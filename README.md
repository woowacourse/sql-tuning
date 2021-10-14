# 🚀 조회 성능 개선하기

## 실습 환경
M1 Mac에서 workbench로 EC2에 띄워져있는 docker mysql에 연결하여 진행하였습니다.

## A. 쿼리 연습

```sql
-- tuning 데이터베이스 사용
USE tuning;
```

> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)

### 1. 쿼리 작성만으로 1s 이하로 반환한다.

#### 쿼리
```sql
SELECT
    `활동중인 부서의 현재 부서관리자 정보`.사원번호, `활동중인 부서의 현재 부서관리자 정보`.이름, `활동중인 부서의 현재 부서관리자 정보`.연봉, `활동중인 부서의 현재 부서관리자 정보`.직급명, `입출입 정보`.입출입시간, `입출입 정보`.지역, `입출입 정보`.입출입구분
FROM(
    SELECT
        `활동중인 부서의 현재 부서관리자 사원번호`.사원번호, 사원.이름, 급여.연봉, 직급.직급명
    FROM(
        SELECT
            사원번호
        FROM (SELECT 부서번호 FROM 부서 WHERE 비고 = 'active') AS 부서
        JOIN (SELECT 사원번호, 부서번호 FROM 부서관리자 WHERE 종료일자 = '9999-01-01') AS 부서관리자
            ON 부서.부서번호 = 부서관리자.부서번호
    ) AS `활동중인 부서의 현재 부서관리자 사원번호`
    JOIN (SELECT 사원번호, 이름 FROM 사원) AS 사원
        ON `활동중인 부서의 현재 부서관리자 사원번호`.사원번호 = 사원.사원번호
    JOIN (SELECT 사원번호, 직급명 FROM 직급 WHERE 종료일자 = '9999-01-01') AS 직급
        ON `활동중인 부서의 현재 부서관리자 사원번호`.사원번호 = 직급.사원번호
    JOIN (SELECT 사원번호, 연봉 FROM 급여 WHERE 종료일자 = '9999-01-01') AS 급여
         ON `활동중인 부서의 현재 부서관리자 사원번호`.사원번호 = 급여.사원번호
    ORDER BY 연봉 DESC
    LIMIT 0, 5
) AS `활동중인 부서의 현재 부서관리자 정보`
JOIN (SELECT 사원번호, 입출입시간, 지역, 입출입구분 FROM 사원출입기록 WHERE 입출입구분 = 'O') AS `입출입 정보`
    ON `입출입 정보`.사원번호 = `활동중인 부서의 현재 부서관리자 정보`.사원번호
ORDER BY 연봉 DESC;
```

#### 실행결과
<img width="427" alt="스크린샷 2021-10-13 오후 9 22 02" src="https://user-images.githubusercontent.com/45876793/137131312-d7ff977b-d936-432a-a780-d74caddd1c9d.png">

<img width="1091" alt="스크린샷 2021-10-13 오후 9 24 42" src="https://user-images.githubusercontent.com/45876793/137131755-c868e0a4-8ec0-4aba-bc48-8bbdc2d5a7fe.png">

<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

### 2. 인덱스 설정을 추가하여 50 ms 이하로 반환한다.

#### 실행계획 분석

![v1](https://user-images.githubusercontent.com/45876793/137131989-d0e9e238-406c-49bd-b5e1-0eb6bd9539b3.png)

<img width="972" alt="스크린샷 2021-10-13 오후 9 27 02" src="https://user-images.githubusercontent.com/45876793/137132067-f336ac95-07e6-40f7-a89f-ba59bc845ea6.png">

- 많은 rows를 스캔하고 있는 사원출입기록에 인덱스를 걸어주었습니다. 사원번호를 통해 JOIN을 하고 있기 때문에 JOIN 연결 키에 아래와 같이 인덱스를 만들어주었습니다.
```sql
CREATE INDEX `idx_사원출입기록_사원번호` on `tuning`.`사원출입기록` (사원번호);
```

#### 실행결과

![v2](https://user-images.githubusercontent.com/45876793/137132475-d50bfbd4-507e-412e-9270-2d81bc6364e2.png)

<img width="1119" alt="스크린샷 2021-10-13 오후 9 29 48" src="https://user-images.githubusercontent.com/45876793/137132514-f40e1424-d5f4-41eb-8641-a839706b8343.png">

<img width="1090" alt="스크린샷 2021-10-13 오후 9 23 49" src="https://user-images.githubusercontent.com/45876793/137131646-0f51ea11-cf5d-4a62-bb11-476239f4cdb5.png">

<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

## B. 인덱스 설계

```sql
-- subway 데이터베이스 사용
USE subway;
```

### * 요구사항

- [x] 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환

    - [x] [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.

    - [x] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)

    - [x] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

    - [x] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

    - [x] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

### 1. Coding as a Hobby 와 같은 결과를 반환하세요.

#### 쿼리 & 결과
```sql
SELECT
    hobby, 
    ROUND(COUNT(*) * 100 / total.count, 1) AS percent
FROM
    programmer
JOIN
    (SELECT COUNT(*) AS count FROM programmer) AS total
GROUP BY hobby, count;
```
<img width="105" alt="스크린샷 2021-10-13 오후 10 47 14" src="https://user-images.githubusercontent.com/45876793/137145681-f41e2f14-3fc7-4e21-aad0-0a188ad95d6a.png">

#### 실행결과(before)
![v1](https://user-images.githubusercontent.com/45876793/137146169-065133f5-93a3-4a4d-ba63-14c20695e3b5.png)

<img width="737" alt="스크린샷 2021-10-13 오후 10 50 54" src="https://user-images.githubusercontent.com/45876793/137146178-373dcc43-4acb-44c6-87e8-5a1081d97b4e.png">

<img width="983" alt="스크린샷 2021-10-13 오후 10 47 38" src="https://user-images.githubusercontent.com/45876793/137145693-4bc2bf05-62a3-4595-9008-7b78196ebcd9.png">

#### 개선하기
현재 `programmer` 테이블을 hobby를 통해 구분짓고 있습니다. 이때 hobby에 대한 인덱스가 걸려있지 않기 때문에 전체 테이블을 Full Scan한 후, 필터를 걸어준다고 생각이됩니다. 따라서 hobby에 대해 인덱스를 만들어줬습니다.

```sql
CREATE INDEX `idx_programmer_hobby`  ON `subway`.`programmer` (hobby);
```

추가적으로 `전체 프로그래머 수를 구하기 위한 서브쿼리`는 hobby 인덱스가 아닌 unique한 값을 이용해주면 성능 향상이 있을 것이라 생각해 `programmer` 테이블의 id에 pk와 unique를 걸어줬습니다.
```sql
ALTER TABLE `subway`.`programmer` 
CHANGE COLUMN `id` `id` BIGINT(20) NOT NULL,
ADD PRIMARY KEY (`id`),
ADD UNIQUE INDEX `id_UNIQUE` (`id` ASC);
```
#### 실행결과(after)

![v3](https://user-images.githubusercontent.com/45876793/137187780-d783d3a3-cf16-4511-9a30-a9397b14da70.png)

<img width="733" alt="스크린샷 2021-10-14 오전 2 59 31" src="https://user-images.githubusercontent.com/45876793/137187787-246150f6-d7a0-4978-ab06-8ed252d83bfb.png">

hobby 인덱스, id 인덱스를 사용하여 Table Full Scan에서 Index Full Scan으로 변경된 것을 볼 수 있습니다. 다만 Query Cost는 높아졌습니다.

<img width="982" alt="스크린샷 2021-10-14 오전 2 59 07" src="https://user-images.githubusercontent.com/45876793/137188077-80227813-0a95-4cad-ad3d-11cfc61ca25d.png">

### 2. 프로그래머별로 해당하는 병원 이름을 반환하세요.

#### 쿼리 & 결과
```sql
SELECT
  c.programmer_id, hospital.name AS hospital_name
FROM
    (SELECT hospital_id, programmer_id FROM covid) AS c
JOIN hospital
    ON hospital.id = c.hospital_id
JOIN (SELECT id FROM programmer) AS p
    ON p.id = c.programmer_id
```
<img width="183" alt="스크린샷 2021-10-14 오전 4 04 51" src="https://user-images.githubusercontent.com/45876793/137197184-5017220c-a3b8-4cc8-b8b2-973f615d4a96.png">

#### 실행결과(before)

![init](https://user-images.githubusercontent.com/45876793/137287995-9e2722fe-e2aa-4edc-a81d-530024cb447b.png)

<img width="988" alt="스크린샷 2021-10-14 오후 6 14 33" src="https://user-images.githubusercontent.com/45876793/137288001-fe936363-71b8-454a-abc9-f420f2a50728.png">

<img width="1119" alt="스크린샷 2021-10-14 오후 6 16 16" src="https://user-images.githubusercontent.com/45876793/137288334-8437bd4a-2059-445e-b287-9a7f7b540b63.png">

#### 개선하기

실행계획을 보면 `hospital` - `covid` - `programmer` 순으로 쿼리가 실행됩니다. 먼저 `hospital`의 Full Table Scan을 인덱스를 걸어 바꿔줬습니다. `hospital`은 id를 통해 비교하고 있기 때문에 id 칼럼을 pk, unique로 두어 인덱스를 걸어줬습니다.

```sql
ALTER TABLE `subway`.`hospital` 
CHANGE COLUMN `id` `id` INT(11) NOT NULL ,
ADD PRIMARY KEY (`id`),
ADD UNIQUE INDEX `id_UNIQUE` (`id` ASC);
```

이후 실행계획을 보면 실행 순서가 `covid` - `hospital` - `programmer` 순으로 바뀐걸 볼 수 있습니다.

<img width="808" alt="스크린샷 2021-10-14 오후 6 18 38" src="https://user-images.githubusercontent.com/45876793/137288830-10d48716-35fc-4ac5-a07b-a533688aecb3.png">

`covid`는 여전히 Full Table Scan을 하고 있기때문에 `covid`에도 인덱스를 걸어줬습니다. `programmer`의 id와 `programmer_id`를 통해, `hospital`의 id와 `hospital_id`를 통해 JOIN하고 있고 `programmer`의 id와 `hospital`의 id는 이미 인덱스로 등록되어 있으므로, (`programmer_id`, `hospital_id`) 인덱스를 만들어줬습니다.

```sql
CREATE INDEX `idx_covid_programmer_id_hospital_id`  ON `subway`.`covid` (programmer_id, hospital_id);
```

#### 실행결과(after)

![explain](https://user-images.githubusercontent.com/45876793/137291258-a209cb32-a3ab-4fd8-8d70-23bb0eb24177.png)

<img width="1047" alt="스크린샷 2021-10-14 오후 6 31 50" src="https://user-images.githubusercontent.com/45876793/137291274-8b9c117f-c3ab-4869-b486-45ab7c28c3b1.png">

Table Full Scan이 없어진 것을 볼 수 있습니다.

<img width="1150" alt="스크린샷 2021-10-14 오후 6 32 42" src="https://user-images.githubusercontent.com/45876793/137291288-ea98c3f7-38fc-45cf-9ac4-450e2d110950.png">

### 3. 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요.
#### 쿼리 & 결과
```sql
SELECT
  p.id, hospital.name AS hospital_name
FROM
  (SELECT hospital_id, programmer_id FROM covid WHERE programmer_id IS NOT NULL) AS c
    JOIN (SELECT id FROM programmer WHERE (hobby = 'Yes' AND student LIKE 'Yes%') OR years_coding = '0-2 years') AS p
        ON c.programmer_id = p.id
    JOIN hospital
        ON hospital.id = c.hospital_id
```
<img width="142" alt="스크린샷 2021-10-14 오전 7 34 37" src="https://user-images.githubusercontent.com/45876793/137221842-d4bf6756-13f4-4836-94bb-b55b80260acf.png">

#### 실행결과
![explain](https://user-images.githubusercontent.com/45876793/137221923-f90cb719-fdbd-43f6-880a-1e395e5272d8.png)

<img width="1105" alt="스크린샷 2021-10-14 오전 7 37 00" src="https://user-images.githubusercontent.com/45876793/137222007-f1891d88-1435-42cd-ad06-c54d677bfe9e.png">

이전 문제에서 `idx_covid_programmer_id_hospital_id`와 `hospital` pk를 등록했었기 때문에 결과가 잘 나왔습니다. 추가적으로 `programmer`의 Full Table Scan을 바꿔보고 싶었으나 OR 조건을 사용하고 있어서 Full Scan을 할 수 밖에 없는 것 같습니다.

<img width="1056" alt="스크린샷 2021-10-14 오전 7 34 26" src="https://user-images.githubusercontent.com/45876793/137221832-d5b8c2db-ff0f-4b66-b9a3-cc236fc5cce5.png">

### 4. 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요.
#### 쿼리 & 결과
```sql
SELECT
    c.stay AS period, COUNT(c.id) AS number_of_people
FROM (SELECT id, hospital_id, member_id, programmer_id, stay FROM covid) AS c
JOIN (SELECT id FROM hospital WHERE name = '서울대병원') AS seoul_hospital
	ON seoul_hospital.id = c.hospital_id
JOIN (SELECT id FROM member WHERE age BETWEEN 20 AND 29) AS twenties
	ON twenties.id = c.member_id
JOIN (SELECT id FROM programmer WHERE country = 'India') AS indian
     ON indian.id = programmer_id
GROUP BY period
```
<img width="232" alt="스크린샷 2021-10-14 오전 8 13 18" src="https://user-images.githubusercontent.com/45876793/137225134-d7231bbf-4977-4ec2-ba46-7dda08c12556.png">

#### 실행결과(before)
![explain](https://user-images.githubusercontent.com/45876793/137225200-aa9232ed-d7f7-4dbc-a10a-90d6efce66c0.png)

<img width="1192" alt="스크린샷 2021-10-14 오전 8 14 14" src="https://user-images.githubusercontent.com/45876793/137225205-4eefda6e-e27b-4e92-aef0-08c07931dd95.png">

<img width="979" alt="스크린샷 2021-10-14 오전 8 15 46" src="https://user-images.githubusercontent.com/45876793/137225337-23a0d33b-0c72-47b3-8bc6-a9ae4e4575ca.png">

#### 개선하기
실행계획을 보면 `programmer` - `covid` - `member` - `hospital` 순으로 쿼리가 실행됩니다. 먼저 `programmer`의 Full Table Scan을 없애주기 위해 인덱스를 걸어줬습니다. `programmer`의 경우 WHERE 절에서 country를 사용하고 있으므로 `country`에 인덱스를 걸어줬습니다.

```sql
CREATE INDEX `idx_programmer_country` ON `subway`.`programmer` (country);
```

이후 실행계획을 보면 `programmer`는 인덱스를 사용하게 변한걸 볼 수 있습니다.

<img width="1195" alt="스크린샷 2021-10-14 오후 4 45 49" src="https://user-images.githubusercontent.com/45876793/137273828-1fa10125-30a2-4de9-8d57-f0ff096699d9.png">

이어서 `hospital`에도 인덱스를 걸어줬습니다. `hospital`은 WHERE절에서 name을 사용하고 있으므로 `name`에 인덱스를 걸어줬습니다.

이때 `name`이 현재 TEXT 타입이어서 인덱스를 걸 수 없기 때문에 먼저 `name`의 타입을 varchar로 변경해주고 인덱스를 만들어줬습니다.
```sql
ALTER TABLE `subway`.`hospital` 
CHANGE COLUMN `name` `name` VARCHAR(255) NULL DEFAULT NULL;
```
```sql
CREATE INDEX `idx_hospital_name` ON `subway`.`hospital` (name);
```
실행계획을 보면 두 개의 인덱스를 추가하고 나서 실행 순서가 바뀌면서 멀쩡하던 `covid`가 Full Table Scan으로 변했습니다.

<img width="1153" alt="스크린샷 2021-10-14 오후 5 13 58" src="https://user-images.githubusercontent.com/45876793/137278157-f3d4f6a3-e312-459e-82e6-0d567fe1cef8.png">

`covid`는 먼저 `hospital_id`, `programmer_id`, `member_id`를 통해 JOIN 하기 때문에 (`hospital_id`, `programmer_id`, `member_id`)인덱스를 만들어줬습니다.

```sql
CREATE INDEX `idx_covid_hospital_id_programmer_id_member_id`  ON `subway`.`covid` (hospital_id, programmer_id, member_id);
```

이후 실행계획을 보면 Table Full Scan이 없어진 것을 볼 수 있습니다.

<img width="1217" alt="스크린샷 2021-10-14 오후 5 45 35" src="https://user-images.githubusercontent.com/45876793/137283284-802fa988-6432-4a8b-a408-6646c09a713f.png">

추가적으로 실행계획을 보면 `member`의 filtered가 비효율적인 것을 볼 수 있습니다. `member`에서는 age에 BETWEEN 구문을 쓰고 있기 때문에 age에 인덱스를 걸어 정렬되도록 하였습니다.

#### 실행결과(after)
![explain](https://user-images.githubusercontent.com/45876793/137283571-0fe5b004-0aeb-4bd0-89ae-ae46d8e061a2.png)

<img width="1216" alt="스크린샷 2021-10-14 오후 5 44 15" src="https://user-images.githubusercontent.com/45876793/137283373-78861ba5-b594-4480-9b23-a1353dce99f4.png">

<img width="983" alt="스크린샷 2021-10-14 오전 8 57 56" src="https://user-images.githubusercontent.com/45876793/137228631-883b4c93-4740-4e0e-ab78-cfc534da4713.png">


### 5. 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요.

#### 쿼리 & 결과 
```sql
SELECT
    p.exercise AS exercise, COUNT(c.id) AS number_of_exercises
FROM (SELECT id, hospital_id, member_id, programmer_id FROM covid) AS c
JOIN (SELECT id FROM hospital WHERE name = '서울대병원') AS seoul_hospital
    ON seoul_hospital.id = c.hospital_id
JOIN (SELECT id FROM member WHERE age BETWEEN 30 AND 39) AS thirties
    ON thirties.id = c.member_id
JOIN (SELECT id, exercise FROM programmer) AS p
    ON p.id = programmer_id
GROUP BY p.exercise
```
<img width="266" alt="스크린샷 2021-10-14 오전 9 14 55" src="https://user-images.githubusercontent.com/45876793/137229747-fccf5e8a-e5d2-4243-8026-87fd6f638078.png">

#### 실행결과

![explain](https://user-images.githubusercontent.com/45876793/137284497-95ebdc57-295b-4abb-bccc-73be1c1a29c1.png)

<img width="1217" alt="스크린샷 2021-10-14 오후 5 52 37" src="https://user-images.githubusercontent.com/45876793/137284506-1fac9494-b5c9-46e8-bcea-049527464bae.png">

이전 과정에서 만들었던 인덱스들이 잘 동작하여 따로 인덱스를 추가하지 않았습니다.

<img width="981" alt="스크린샷 2021-10-14 오후 5 57 44" src="https://user-images.githubusercontent.com/45876793/137285338-38fd3bce-d780-4c11-b0d8-0d44474d7842.png">
