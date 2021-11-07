# 🚀 조회 성능 개선하기

## A. 쿼리 연습
1. 쿼리 작성만으로 1s 이하로 반환한다.
2. 인덱스 설정을 추가하여 50 ms 이하로 반환한다
> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)

### 작성 쿼리
```sql
select 활동부서_상위_연봉_관리자.사원번호, 활동부서_상위_연봉_관리자.이름, 활동부서_상위_연봉_관리자.연봉, 활동부서_상위_연봉_관리자.직급명, 사원출입기록.입출입시간, 사원출입기록.지역
from (select 부서관리자.사원번호, 사원.이름, 급여.연봉, 직급.직급명 from 부서관리자
		left join 사원 on 사원.사원번호 = 부서관리자.사원번호
		left join 부서 on (부서.부서번호 = 부서관리자.부서번호 and 부서.비고 = 'active')
		left join 직급 on (부서관리자.사원번호 = 직급.사원번호)
		left join 급여 on (부서관리자.사원번호 = 급여.사원번호)
		where 부서관리자.종료일자 > '2021-10-11' and 급여.종료일자 > '2021-10-11' and 직급.종료일자 > '2021-10-11' and 부서.부서번호 is not null
		order by 급여.연봉 desc limit 5) as 활동부서_상위_연봉_관리자
	left join 사원출입기록 ON (사원출입기록.사원번호 = 활동부서_상위_연봉_관리자.사원번호 and 사원출입기록.입출입구분 = 'O')
    order by 활동부서_상위_연봉_관리자.연봉 desc
    
-- 사원출입기록에 사원번호 인덱스 생성
```

### 결과

![스크린샷 2021-10-11 오후 11 09 47](https://user-images.githubusercontent.com/67272922/136804695-db774bca-0ea7-476d-89e6-32efb69aa828.png)

인덱스 적용 전
![스크린샷 2021-10-11 오후 11 29 43](https://user-images.githubusercontent.com/67272922/136807772-97f9cf76-c8d0-46c9-9f95-b69f9c5f0f23.png)

인덱스 적용 후
![스크린샷 2021-10-11 오후 11 31 31](https://user-images.githubusercontent.com/67272922/136807991-bf74a942-d87f-4424-a863-48aea3af65aa.png)


<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>


## B. 인덱스 설계


MySQL Workbench limit 설정을 1000으로 잡고 진행했습니다.


![스크린샷 2021-10-11 오후 11 13 55](https://user-images.githubusercontent.com/67272922/136805377-db54e646-59ba-4af4-aca3-7278cacc47af.png)


### * 요구사항 - 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환


  - [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.


### 작성 쿼리
```sql
select hobby, round((count(hobby) * 100 / (select count(*) from programmer)), 1) as percent
from programmer
group by hobby order by percent desc

-- programmer.id 에 pk, unique 설정
-- programmer.hobby에 인덱스 생성
```


### 결과


![스크린샷 2021-10-11 오후 11 18 04](https://user-images.githubusercontent.com/67272922/136805907-03146603-e3df-41ca-8248-038dac365e0e.png)

![스크린샷 2021-10-11 오후 11 18 54](https://user-images.githubusercontent.com/67272922/136806011-c18fdedc-5d45-4d6c-860f-7c45e48ec254.png)


  - 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)


### 작성 쿼리
```sql
select covid.programmer_id, hospital.name from covid
	left join hospital on hospital.id = covid.hospital_id
    where covid.programmer_id is not null
    limit 10000;

-- hospital.id 에 pk, unique 설정
-- covid.id 에 pk, unique 설정
-- covid.programmer_id, covid.hospital_id 인덱스 생성
```


### 결과


![스크린샷 2021-10-11 오후 11 34 46](https://user-images.githubusercontent.com/67272922/136808488-a948ce30-eb22-4378-93aa-ac3928e2fa16.png)

![스크린샷 2021-10-11 오후 11 33 05](https://user-images.githubusercontent.com/67272922/136808263-757cfdd8-24eb-440b-8493-634fbbe13b05.png)


  - 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)


### 작성 쿼리
```sql
select programmer.id, hospital.name, programmer.hobby, programmer.years_coding, programmer.student from programmer
	left join covid on programmer.id = covid.programmer_id
    left join hospital on covid.hospital_id = hospital.id
    where ((programmer.hobby = 'yes' and programmer.student like('yes%'))
		or programmer.years_coding = '0-2 years') and covid.programmer_id is not null 
        and hospital.name is not null
	order by programmer.id
	limit 1000
```


### 결과


![스크린샷 2021-10-11 오후 11 47 32](https://user-images.githubusercontent.com/67272922/136810534-ba14c218-590e-4649-b0cb-94319a1f92c9.png)

![스크린샷 2021-10-11 오후 11 47 20](https://user-images.githubusercontent.com/67272922/136810549-94a9e849-e8f9-49c3-bda6-e8dd687f076a.png)


  - 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)


### 작성 쿼리
```sql
select covid.stay, count(programmer.id) from hospital
	left join covid on hospital.id = covid.hospital_id
	left join programmer on covid.programmer_id = programmer.id
	left join member on member.id = covid.member_id
    where hospital.name = '서울대병원' and programmer.country = 'India' and member.age between 20 and 29
    group by covid.stay;


-- hospita.name 에 text -> varchar(255)로 변경, 인덱스 생성
-- covid.stay, covid.member_id, covid.programmer_id, covid.hospital_id 에 인덱스 생성
memeber.age 에 인덱싱 생성


```


### 결과

![스크린샷 2021-10-11 오후 11 51 54](https://user-images.githubusercontent.com/67272922/136811174-a2a97f55-a8aa-47bf-8c75-d230cd9e7e14.png)

![스크린샷 2021-10-11 오후 11 51 51](https://user-images.githubusercontent.com/67272922/136811168-90f24326-46ca-400c-a399-f3feb9acaa19.png)



  - 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)


### 작성 쿼리
```sql
select programmer.exercise, count(programmer.id) from hospital
	inner join covid on hospital.id = covid.hospital_id
	inner join programmer on covid.programmer_id = programmer.id
	inner join member on member.id = covid.member_id
    where hospital.name = '서울대병원' and member.age between 30 and 39
    group by programmer.exercise;

-- programmer.exercise 에 text -> varchar(255)로 변경, 인덱스 생성
```


### 결과

![스크린샷 2021-10-11 오후 11 53 45](https://user-images.githubusercontent.com/67272922/136811432-27f73f7b-b4c5-42db-97ac-c28f25ed4ea0.png)
![스크린샷 2021-10-11 오후 11 53 48](https://user-images.githubusercontent.com/67272922/136811437-0be10989-9223-46a0-a31a-2e17e294288a.png)

<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>
