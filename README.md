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

```sql
SELECT emp.사원번호, emp.이름, pay.연봉, lev.직급명, ent.지역, ent.입출입구분, ent.입출입시간
FROM 사원 emp

JOIN (
SELECT 직급.사원번호, 직급.직급명
FROM 직급
WHERE 종료일자 >= '9999-01-01' AND 직급명 = 'Manager'
) AS lev ON emp.사원번호 = lev.사원번호

JOIN (
	SELECT 사원번호, 연봉
	FROM 급여
	WHERE 종료일자 >= '9999-01-01'
	ORDER BY 연봉 DESC
) AS pay ON pay.사원번호 = emp.사원번호

JOIN (
	SELECT 사원번호, 지역, 입출입구분, 입출입시간
	FROM 사원출입기록
    WHERE 입출입구분 = 'O'
	ORDER BY 입출입시간 DESC
) AS ent ON ent.사원번호 = emp.사원번호

WHERE emp.사원번호 IN (
	SELECT man.사원번호
    FROM 부서관리자 man
    WHERE man.부서번호 IN (
		SELECT par.부서번호
        FROM 부서 par
        WHERE par.비고 = 'active'
	)
)

ORDER BY pay.연봉 DESC
```
![1](https://user-images.githubusercontent.com/49058669/137623272-0eceee15-f0ac-4d9b-a62c-773dcf81f0f5.png)
)

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

실습 예시를 기준으로 작업해서 5 → 4 → 3 → 2 → 1 순으로 미션을 진행했습니다. 그래서 먼저 Index tuning 을 건드린 여파로 뒤쪽 미션은 별다른 Index tuning 없이 시간을 만족했습니다.

해당 미션은 M1 으로 진행하여 요구 시간(100ms 이하)를 맞추기 어려운 이슈가 있습니다. 따라서 약간 더 시간이 나오는 점 감안해주면 감사하겠습니다.

1. 기본 쿼리 설계

```sql
SELECT hobby AS "취미", CONCAT((round(count(*) * 100 / (
	select count(*)
  from programmer
), 1)), '%') AS "퍼센티지"
FROM programmer
GROUP BY hobby
ORDER BY NULL;
```

- 쿼리

![2](https://user-images.githubusercontent.com/49058669/137623315-a40a03c1-a7ad-4aca-9c19-80efc44bc780.png)

![3](https://user-images.githubusercontent.com/49058669/137623318-d8ba7d85-0a35-4bc2-9c4c-20fc038d3acb.png)

![4](https://user-images.githubusercontent.com/49058669/137623319-d4668c4e-0ffa-40b9-aee8-ab8e3a9bb3b2.png)
)

- `programmer` id(PK, NN, UQ) 설정
- `programmer` hobby index 추가
- 쿼리 마지막에 `ORDER BY NULL` 추가

1. 기본 쿼리 설계

```sql
SELECT C.id AS "프로그래머 ID", H.name AS "병원"
FROM (SELECT id, member_id FROM programmer) AS P
JOIN (SELECT id, programmer_id, hospital_id FROM covid) AS C
ON P.id = C.programmer_id
JOIN (SELECT id, name FROM hospital) AS H
ON H.id = C.hospital_id
ORDER BY NULL;
```

- 쿼리

![5](https://user-images.githubusercontent.com/49058669/137623348-e5899764-de84-4e41-92de-c945e7ee0c8c.png)

![6](https://user-images.githubusercontent.com/49058669/137623353-233941f3-d20b-4bd9-9c63-a44e0c8e94e6.png)

- `hospital` index type 변경 및 index 설정 : text → VARCHAR(255)
- `hospital` id (PK, NN, UQ), name (UQ) 설정
- 쿼리 마지막에 `ORDER BY NULL` 추가

1. 기본 쿼리 설계

```sql
초기에 이렇게 만들었는데 시간초과가 발생했다.

SELECT C.id AS "프로그래머 ID", H.name AS "병원", P.hobby AS "취미", P.dev_type AS "개발 종류", P.years_coding AS "년차"
FROM (SELECT id FROM member) AS M
JOIN (SELECT id, member_id, hobby, dev_type, years_coding FROM programmer WHERE (hobby = true AND student = true) OR (years_coding = '0-2 years')) AS P
ON M.id = P.member_id
JOIN (SELECT id, member_id, hospital_id FROM covid) AS C
ON M.id = C.member_id
JOIN (SELECT id, name FROM hospital) AS H
ON C.hospital_id = H.id;

두 번째 JOIN 문을 member로 매핑하지 않고 programmer_id 로 매핑하니 해결되었다. 왜일까?
```

```sql
SELECT C.id AS "프로그래머 ID", H.name AS "병원", P.hobby AS "취미", P.dev_type AS "개발 종류", P.years_coding AS "년차"
FROM (SELECT id FROM member) AS M
JOIN (SELECT id, member_id, hobby, dev_type, years_coding FROM programmer WHERE (hobby = true AND student = true) OR (years_coding = '0-2 years')) AS P
ON M.id = P.member_id
JOIN (SELECT id, programmer_id, hospital_id FROM covid) AS C
ON P.id = C.programmer_id
JOIN (SELECT id, name FROM hospital) AS H
ON C.hospital_id = H.id
ORDER BY NULL;
```

- 튜닝

![7](https://user-images.githubusercontent.com/49058669/137623354-e4637903-c158-48db-9636-683815318262.png)

![8](https://user-images.githubusercontent.com/49058669/137623358-7582944a-992f-4c84-997e-4a0aa019f80d.png)

- `programmer` hobby type 변경 : text → VARCHAR
- `programmer` id(PK, NN, UQ), member_id(UQ) 설정
- 쿼리 마지막에 `ORDER BY NULL` 추가

1. 기본 쿼리 설계

```sql
SELECT stay AS "병원에 머문 기간", COUNT(C.id) AS "인원수 집계"
FROM (SELECT id FROM member WHERE age BETWEEN 20 AND 29) AS M
JOIN (SELECT id, member_id, programmer_id, stay FROM covid) AS C
ON C.member_id = M.id
JOIN (SELECT id FROM programmer WHERE country = 'india') AS P
ON C.programmer_id = P.id
JOIN (SELECT id FROM hospital WHERE name = '서울대병원') as H
ON C.hospital_id = H.id
GROUP BY stay
ORDER BY NULL;
```

- 튜닝

![9](https://user-images.githubusercontent.com/49058669/137623385-47fa9b5e-442b-41e1-a8d6-abca7b512a10.png)

![10](https://user-images.githubusercontent.com/49058669/137623387-f938ed5e-ef9e-40e7-a50c-c989eb6f2265.png)

![11](https://user-images.githubusercontent.com/49058669/137623390-8a5bb258-7157-4ded-8edb-e5a3a3c9ca96.png)

- `hospital` index type 변경 및 index 설정 : text → VARCHAR(255)
- `hospital` id (PK, NN, UQ), name (UQ) 설정
- `covid` hospital_id, member_id index 설정
- `programmer` country index 설정
- 쿼리 마지막에 `ORDER BY NULL` 추가

1. 기본 쿼리 설계

```sql
SELECT exercise AS "운동 주기", COUNT(P.id) AS "인원수 집계"
FROM (SELECT id FROM member WHERE age BETWEEN 30 AND 39) AS M
JOIN (SELECT member_id, hospital_id, programmer_id FROM covid) AS C
ON C.member_id = M.id
JOIN (SELECT id, exercise FROM programmer) AS P
ON C.programmer_id = P.id
JOIN (SELECT id FROM hospital WHERE name = '서울대병원') as H
ON C.hospital_id = H.id
GROUP BY exercise
ORDER BY NULL;
```

- 튜닝

![12](https://user-images.githubusercontent.com/49058669/137623392-3d8414e2-9e8c-4a21-b9cf-da798fbb17ef.png)

![13](https://user-images.githubusercontent.com/49058669/137623395-a86a7ae3-19bd-4562-b8f0-c209d8d78bc9.png)

![14](https://user-images.githubusercontent.com/49058669/137623398-fbc4b7c7-1ba6-456f-ae69-2cfc791185a3.png)

- `hospital` index type 변경 및 index 설정 : text → VARCHAR(255)
- `hospital` id (PK, NN, UQ), name (UQ) 설정
- `covid` hospital_id, member_id index 설정
- 쿼리 마지막에 `ORDER BY NULL` 추가

<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

## C. 프로젝트 요구사항

### a. 페이징 쿼리를 적용 

### b. Replication 적용 
