# 🚀 조회 성능 개선하기

## 실습 환경
M1 Mac에서 workbench로 EC2에 띄워져있는 docker mysql에 연결하여 진행하였습니다.

## A. 쿼리 연습
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

### * 요구사항

- [ ] 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환

    - [x] [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.

    - [ ] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)

    - [ ] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

    - [ ] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

    - [ ] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

### Coding as a Hobby 와 같은 결과를 반환하세요.

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

### 프로그래머별로 해당하는 병원 이름을 반환하세요.

#### 쿼리 & 결과
```sql
SELECT
    c.programmer_id, hospital.name AS hospital_name
FROM 
    (SELECT hospital_id, programmer_id FROM covid WHERE programmer_id IS NOT NULL) AS c
JOIN hospital
    ON hospital.id = c.hospital_id
```
<img width="183" alt="스크린샷 2021-10-14 오전 4 04 51" src="https://user-images.githubusercontent.com/45876793/137197184-5017220c-a3b8-4cc8-b8b2-973f615d4a96.png">

#### 실행결과(before)
![v1](https://user-images.githubusercontent.com/45876793/137197353-d0bfc3b1-9561-45d3-811f-4bc6ff02ce4a.png)

<img width="810" alt="스크린샷 2021-10-14 오전 4 06 12" src="https://user-images.githubusercontent.com/45876793/137197357-e0e61797-c44c-4550-93ec-fc6292402494.png">

<img width="1057" alt="스크린샷 2021-10-14 오전 4 39 36" src="https://user-images.githubusercontent.com/45876793/137201778-c18e4eec-75e1-4ecd-a90b-1e87298ded1f.png">

#### 개선하기
먼저 `covid`와 `hospital`의 id에 pk, unique를 추가해줍니다.
```sql
ALTER TABLE `subway`.`covid` 
CHANGE COLUMN `id` `id` BIGINT(20) NOT NULL ,
ADD PRIMARY KEY (`id`),
ADD UNIQUE INDEX `id_UNIQUE` (`id` ASC);
```
```sql
ALTER TABLE `subway`.`hospital` 
CHANGE COLUMN `id` `id` INT(11) NOT NULL ,
ADD PRIMARY KEY (`id`),
ADD UNIQUE INDEX `id_UNIQUE` (`id` ASC);
```

`covid`는 `programmer_id`와 `hospital_id`를 사용하므로 인덱스를 만들어줍니다. pk를 추가해준 후 실행계획을 보면 `covid` - `hospital` 순으로 쿼리가 실행됩니다. 따라서 `covid`의 WHERE 절에서 사용되는 `programmer_id`, JOIN의 ON절에서 사용되는 `hospital_id` 순서로 복합 인덱스를 만들어줍니다.

```sql
CREATE INDEX `idx_covid_programmer_id_hospital_id`  ON `subway`.`covid` (programmer_id, hospital_id);
```

#### 실행결과(after)

![explain](https://user-images.githubusercontent.com/45876793/137200159-a6b67c0b-a361-423f-bb6b-884888b92915.png)

<img width="965" alt="스크린샷 2021-10-14 오전 4 25 36" src="https://user-images.githubusercontent.com/45876793/137200161-0a66d8a9-6bde-4830-b992-1cb4b66b347b.png">

`covid`는 Table Full Scan에서 Index Range Scan으로, `hospital`은 Table Full Scan에서 Unique Scan으로 변경된 것을 볼 수 있습니다. 시간은 이전과 큰 차이가 없는 모습입니다.

<img width="1059" alt="스크린샷 2021-10-14 오전 4 28 31" src="https://user-images.githubusercontent.com/45876793/137200257-e3cb60ae-3427-444e-8e00-a70a98b33a96.png">

### 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요.
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

### 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)
#### 쿼리
#### 인덱스

### 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)
#### 쿼리
#### 인덱스
