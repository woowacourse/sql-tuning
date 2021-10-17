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
```sql
SELECT TOP5.사원번호, TOP5.이름, TOP5.연봉, TOP5.직급명, 사원출입기록.입출입시간, 사원출입기록.지역, 사원출입기록.입출입구분 
FROM 사원출입기록
inner join 
  (SELECT 부서관리자.사원번호, 사원.이름, 급여.연봉, 직급.직급명 
  FROM 부서관리자
  inner join 부서 on 부서관리자.부서번호=부서.부서번호 
  inner join 급여 on 부서관리자.사원번호=급여.사원번호
  inner join 직급 on 부서관리자.사원번호=직급.사원번호
  inner join 사원 on 부서관리자.사원번호=사원.사원번호
  where 부서관리자.종료일자='9999-01-01' AND 급여.종료일자='9999-01-01' AND 직급.종료일자='9999-01-01' AND 부서.비고='ACTIVE'
  order by 급여.연봉 desc limit 5) as TOP5 
on 사원출입기록.사원번호 = TOP5.사원번호
where 사원출입기록.입출입구분='O'
order by TOP5.연봉 DESC;
```
- 결과: 0.325sec
![Screenshot from 2021-10-18 01-42-08](https://user-images.githubusercontent.com/49307266/137636777-98d9c6a5-d406-4942-a39f-494f68374eec.png)

2. 인덱스 설정을 추가하여 50 ms 이하로 반환한다.

- 문제 분석 : 사원출입기록에서 테이블 FULL SCAN에서 너무 많은 비용 발생 -> 사원번호로 index 추가
![db-tuning](https://user-images.githubusercontent.com/49307266/137636866-a7fb7fb4-0da8-45b4-9614-8d0e861fcefe.png)
![Screenshot from 2021-10-18 01-48-59](https://user-images.githubusercontent.com/49307266/137637006-4fc7a5d2-8ffd-46af-864b-8be7ea1b9464.png)

- index 추가
`CREATE INDEX `idx_사원출입기록_사원번호`  ON `tuning`.`사원출입기록` (사원번호) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT`

- 결과: 0.0015sec
![Screenshot from 2021-10-18 01-51-20](https://user-images.githubusercontent.com/49307266/137637091-c28670b7-72e2-4706-8cd5-636b52168737.png)

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

    - [ ] [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.

    - [ ] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)

    - [ ] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

    - [ ] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

    - [ ] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

## C. 프로젝트 요구사항

### a. 페이징 쿼리를 적용 

### b. Replication 적용 
