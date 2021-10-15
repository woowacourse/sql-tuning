# 🚀 조회 성능 개선하기

## A. 쿼리 연습

### * 실습환경 세팅

```sh
$ docker run -d -p 23306:3306 brainbackdoor/data-tuning:0.0.1
```
- [workbench](https://www.mysql.com/products/workbench/)를 설치한 후 localhost:23306 (ID : user, PW : password) 로 접속합니다.

<div style="line-height:1em"><br style="clear:both" ></div>

> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)

1. 쿼리 작성만으로 1s 이하로 반환한다.
2. 인덱스 설정을 추가하여 50 ms 이하로 반환한다.

### 쿼리작성(인덱스 적용 X)

```sql
# 조회 쿼리
select 
    사원.사원번호 as 사원번호, 
    사원.이름 as 이름,
    상위연봉부서관리자.연봉 as 연봉,
    직급.직급명 as 직급명,
    사원출입기록.입출입시간 as 입출입시간,
    사원출입기록.지역 as 지역,
    사원출입기록.입출입구분 as 입출입구분
from 
    사원 
inner join 
	(select
	    부서관리자.사원번호,
    	급여.연봉
	from 
        부서
	inner join 
        부서관리자 on 부서.부서번호 = 부서관리자.부서번호
	inner join 
        급여 on 급여.사원번호 = 부서관리자.사원번호
	inner join 
        사원 on 사원.사원번호 = 부서관리자.사원번호
	where 
        부서.비고 = 'active'
    and 
        급여.종료일자 > now()
    and 
        부서관리자.종료일자 > now()
	group by 부서관리자.사원번호, 급여.연봉
	order by 급여.연봉 desc
	limit 5) as 상위연봉부서관리자
on 상위연봉부서관리자.사원번호 = 사원.사원번호
inner join 
    사원출입기록 on 사원.사원번호 = 사원출입기록.사원번호 and 사원출입기록.입출입구분 = 'O'
inner join 
    직급 on 사원.사원번호 = 직급.사원번호 and 직급.직급명 = 'Manager'
order by 연봉 desc;
```
### 쿼리 결과
<img width="154" alt="스크린샷 2021-10-14 오전 10 15 10" src="https://user-images.githubusercontent.com/56679885/137234103-cf1acddc-4965-4630-9a20-cde47b4fc9b0.png">

Duration: 0.508 ~ 0.530 sec

#### 실행계획
**시각화**
<img width="1397" alt="스크린샷 2021-10-13 오후 9 01 20" src="https://user-images.githubusercontent.com/56679885/137128563-ecdd266f-250f-4af7-846a-535552cfa142.png">

**Explain**
<img width="1355" alt="스크린샷 2021-10-15 오전 1 32 55" src="https://user-images.githubusercontent.com/56679885/137359398-930d62c5-6278-4cb6-9880-7049e5d4454f.png">

### 인덱스 적용
<img width="1355" alt="1-인덱스 적용 전" src="https://user-images.githubusercontent.com/56679885/137370160-bedecb9a-e7e6-4aed-93f4-1d3cc0c7df74.png">

실행계획을 보니 `사원출입기록`을 join 하는 과정에서 full table scan(type = ALL)이 일어나며 658,935 건이나 되는 row를 탐색하고 있었다. 그리고 필터율은 1% 밖에 되지 않았다.
join 조건으로 거는 `사원출입기록`테이블의 `사원번호` 컬럼이 문제인 듯 했다. `사원번호`에 인덱스를 걸어서 테스트해보았다.

```sql
# 인덱스 생성
ALTER TABLE `tuning`.`사원출입기록` 
ADD INDEX `I_사원번호` (`사원번호` ASC);
```

![explain](https://user-images.githubusercontent.com/56679885/137371513-2a93206f-e013-47ac-99b4-2210edc4914d.png)

<img width="1326" alt="2-사원번호 인덱스 적용" src="https://user-images.githubusercontent.com/56679885/137370549-95241b71-af04-4582-8761-93676b75493c.png">

인덱스 적용 후 실행계획을 보았다. 드리븐 테이블(`사원출입기록`)에서 PK 혹은 인덱스로 조인을 걸게 되었다(type = ref). 탐색하는 row 수도 4건으로 줄었다.
쿼리 Duration도 매우 줄었다.

<img width="153" alt="duration-2" src="https://user-images.githubusercontent.com/56679885/137371092-8da1fd05-5eff-45a1-bd3b-59924a707702.png">

Duration: 0.0033 ~ 0.0071 sec


### 이슈

**기존 group by문**
```sql
group by 부서관리자.사원번호
```

위의 group by문 을 사용하여 쿼리하던 중 아래와 같은 에러가 발생하며 쿼리에 실패했다.
> Error Code: 1055. Expression #1 of ORDER BY clause is not in GROUP BY clause and contains nonaggregated column 'tuning.급여.연봉' which is not functionally dependent on columns in GROUP BY clause; this is incompatible with sql_mode=only_full_group_by

검색해보니 mysql 5.7 이상부턴 sql_mode라는게 생겼고, 그 옵션 중 only_full_group_by 때문에 생긴 문제였다.
- [mysql 공식문서](https://dev.mysql.com/doc/refman/5.7/en/group-by-handling.html)
> MySQL rejects queries for which the select list, HAVING condition, or ORDER BY list refer to nonaggregated columns that are neither named in the GROUP BY clause nor are functionally dependent on them.
> 
> 해석: HAVING이나 ORDER BY목록이 GROUP BY절 에서 명명 되지 않았거나 기능적으로 종속되지 않은 집계되지 않은 열을 참조 하는 쿼리를 거부한다. (sql mode가 only_full_group_by일 때)

해결 방법은 3가지다.
1. 쿼리를 수정한다. 집계되지 않은 열을 group by에 추가한다.
2. sql_mode의 only_full_group_by 속성을 끈다.
3. any_value() 함수를 사용하여 집계되지 않는 컬럼을 쿼리한다. any_value()는 컬럼의 데이터 중 아무거나 선택하는 함수다.

select와 order by에서 사용하는 `급여.연봉`을 group by에 추가했다.

**수정한 group by문**
```sql
group by 부서관리자.사원번호, 급여.연봉
```

참고 블로그
https://velog.io/@heumheum2/ONLYFULLGROUPBY

<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

## B. 인덱스 설계

### * 실습환경 세팅

```sh
$ docker run -d -p 13306:3306 brainbackdoor/data-subway:0.0.2
```
- [workbench](https://www.mysql.com/products/workbench/)를 설치한 후 localhost:13306 (ID : root, PW : masterpw) 로 접속합니다.

<div style="line-height:1em"><br style="clear:both" ></div>

### * 요구사항

- [ ] 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환
    - [x] [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.
       
	**조회 쿼리**
	```sql
	SELECT hobby, (COUNT(hobby) / (SELECT COUNT(hobby) FROM programmer)) * 100 AS percentage 
	FROM programmer 
	GROUP BY hobby;
	```

	**인덱스 적용 전**

	<img width="179" alt="스크린샷 2021-10-15 오후 9 32 17" src="https://user-images.githubusercontent.com/56679885/137487258-8f10adf0-8143-4f62-94a1-b9f73a629772.png">
	
	<img width="286" alt="스크린샷 2021-10-15 오후 9 29 41" src="https://user-images.githubusercontent.com/56679885/137486885-5aa82643-7bd6-4f2a-ad1a-a1da8605492b.png">
	
	<img width="987" alt="스크린샷 2021-10-15 오후 9 30 00" src="https://user-images.githubusercontent.com/56679885/137486922-c15080ef-abc9-4697-b858-3658c84088ec.png">
	
	**인덱스 생성**

	```sql
	create index I_hobby on programmer (hobby);
	```

	**인덱스 적용 후**
	
	<img width="176" alt="스크린샷 2021-10-15 오후 9 32 43" src="https://user-images.githubusercontent.com/56679885/137487325-e0e01477-c3d6-4239-931f-e89f558b9f08.png">
	
	<img width="276" alt="스크린샷 2021-10-15 오후 9 31 04" src="https://user-images.githubusercontent.com/56679885/137487065-6db5fcd1-fe08-4c6f-8ab4-e5fafb6ce78d.png">
	
	<img width="1010" alt="스크린샷 2021-10-15 오후 9 31 37" src="https://user-images.githubusercontent.com/56679885/137487153-960b931d-d1a7-4b1b-9b3a-72abeda957a3.png">


    - [ ] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)

    - [ ] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

    - [ ] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

    - [ ] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

## C. 프로젝트 요구사항

### a. 페이징 쿼리를 적용 

### b. Replication 적용 
