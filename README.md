# 🚀 조회 성능 개선하기

## A, B 미션 풀이
[여길 클릭해 이동](https://midi-truck-761.notion.site/SQL-a1fa4ced43ee42098105003999231c41)

## A, B 쿼리

### A1 - 2

```sql
-- 0차
CREATE INDEX idx_access_record_employee_id ON 사원출입기록 (사원번호);

```

```sql
-- 1차 수정 : 피드백 반영. rows 감소. 성능은 평균 0.1ms 정도 차이가 있다.
CREATE INDEX idx_access_record_employee_id_access_turn ON 사원출입기록 (사원번호, 입출입구분);

```

### B - 1

```sql
-- 0차 (수정 X)
CREATE INDEX idx_programmer_hobby ON programmer (hobby);

SELECT 
    hobby,
    count(hobby) / (select count(1) from programmer) as ratio
FROM
    programmer
GROUP BY hobby
ORDER BY ratio desc;

alter table programmer drop index idx_programmer_hobby;


```

### B - 2

```sql
-- 0차
CREATE INDEX idx_covid_programmer ON covid (programmer_id);

SELECT
  programmer.id AS programmer_id,
  hospital.name AS hospital_name
FROM
  covid
    INNER JOIN
  hospital ON covid.hospital_id = hospital.id
    INNER JOIN
  programmer ON covid.programmer_id = programmer.id
ORDER BY programmer.id;

```

```sql
-- 1차 수정 : order by 삭제
-- 궁금해서 programmer_id 대신 hospital_id 에도 인덱싱을 걸어보았는데 별 차이가 없었다.
-- 실행계획에는 차이가 있었다. (노션에 사진 첨부)
CREATE INDEX idx_covid_programmer ON covid (programmer_id);

SELECT
  programmer.id AS programmer_id,
  hospital.name AS hospital_name
FROM
  covid
    INNER JOIN
  hospital ON covid.hospital_id = hospital.id
    INNER JOIN
  programmer ON covid.programmer_id = programmer.id;

```

### B - 3

```sql
-- 0차
CREATE INDEX idx_covid_programmer ON covid (programmer_id);

SELECT
  programmer.id AS user_id,
  programmer.hobby,
  programmer.dev_type,
  programmer.years_coding,
  hospital.name AS hospital_name
FROM
  programmer
    INNER JOIN
  covid ON covid.programmer_id = programmer.id
    INNER JOIN
  hospital ON covid.hospital_id = hospital.id
WHERE
  programmer.hobby = 'yes'
  AND (programmer.dev_type = 'student'
  OR programmer.years_coding = '0-2 years')
ORDER BY programmer.id;


```

```sql
-- 1차 수정 : 피드백 반영. 조회 rows 감소 filtered 증가 (노션에 실행계획 사진 첨부)
-- 성능은 차이 없음
CREATE INDEX idx_covid_programmer ON covid (programmer_id);

SELECT
  programmer.id AS user_id,
  programmer.hobby,
  programmer.dev_type,
  programmer.years_coding,
  hospital.name AS hospital_name
FROM
  programmer
    INNER JOIN
  (SELECT
     covid.id, hospital_id, programmer_id
   FROM
     covid
   WHERE
     programmer_id > 0) as covid ON covid.programmer_id = programmer.id
    INNER JOIN
  hospital ON covid.hospital_id = hospital.id
WHERE
  (programmer.hobby = 'yes'
    AND programmer.dev_type = 'student')
   OR programmer.years_coding = '0-2 years'
ORDER BY programmer.id;


```

### B - 4

```sql
-- 0차
CREATE INDEX idx_covid_hospital ON covid (hospital_id);
CREATE INDEX idx_member_age ON member (age);

SELECT
  covid.stay, COUNT(*)
FROM
  covid
    INNER JOIN
  hospital ON covid.hospital_id = hospital.id
    INNER JOIN
  programmer ON covid.programmer_id = programmer.id
    INNER JOIN
  member ON covid.member_id = member.id
WHERE
  programmer.country = 'India'
  AND hospital.name = '서울대병원'
  AND member.age BETWEEN 20 AND 29
GROUP BY covid.stay;

```

```sql
-- 1차 수정 : 서브쿼리 생성. 서브쿼리 내에서 where 조건절 사용
-- 실행계획과 성능엔 차이가 없었다.
-- 서브쿼리로 수정하면서 hospital.id 대신 programmer.country 에 인덱싱을 걸어보았으나 성능은 더 느려졌다.
CREATE INDEX idx_covid_hospital ON covid (hospital_id);
CREATE INDEX idx_member_age ON member (age);

SELECT
  covid.stay, COUNT(*)
FROM
  covid
    INNER JOIN
    (select id from hospital where name = '서울대병원') as H ON covid.hospital_id = H.id
    INNER JOIN
    (select id from programmer where country = 'India') as P on covid.programmer_id = P.id
    INNER JOIN
    (select id from member where age between 20 and 29) as M on covid.member_id = M.id
GROUP BY covid.stay;

```

### B - 5

```sql
-- 0차(수정X)
CREATE INDEX idx_covid_hospital ON covid (hospital_id);
CREATE INDEX idx_member_age ON member (age);

SELECT
  exercise, COUNT(*)
FROM
  programmer
    INNER JOIN
  covid ON covid.programmer_id = programmer.id
    INNER JOIN
  hospital ON covid.hospital_id = hospital.id
    INNER JOIN
  member ON covid.member_id = member.id
WHERE
  member.age BETWEEN 30 AND 39
  AND hospital.name = '서울대병원'
GROUP BY programmer.exercise;

```

---

## A. 쿼리 연습

### * 실습환경 세팅

```sh
$ docker run -d -p 23306:3306 brainbackdoor/data-tuning:0.0.1
```
- [workbench](https://www.mysql.com/products/workbench/)를 설치한 후 localhost:23306 (ID : user, PW : password) 로 접속합니다.

<div style="line-height:1em"><br style="clear:both" ></div>

> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)


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

- [X] 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환

    - [X] [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.

    - [X] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)

    - [X] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

    - [X] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

    - [X] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

## C. 프로젝트 요구사항

### a. 페이징 쿼리를 적용 

### b. Replication 적용 
