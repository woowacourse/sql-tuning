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


<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

### SQL 작성
```sql
SELECT 재직중인_상위_5위_연봉_관리자.사원번호,
       재직중인_상위_5위_연봉_관리자.이름,
       재직중인_상위_5위_연봉_관리자.연봉,
       재직중인_상위_5위_연봉_관리자.직급명,
       record.지역,
       record.입출입구분,
       record.입출입시간
FROM   (SELECT admin.사원번호,
               grade.직급명,
               employee.이름,
               salary.연봉
        FROM   tuning.부서 AS depart
               JOIN tuning.부서관리자 AS admin
                 ON depart.부서번호 = admin.부서번호
                    AND Lower(depart.비고) = "active"
                    AND admin.종료일자 = "9999-01-01"
               JOIN tuning.급여 AS salary
                 ON admin.사원번호 = salary.사원번호
                    AND salary.종료일자 = "9999-01-01"
               JOIN tuning.직급 AS grade
                 ON admin.사원번호 = grade.사원번호
                    AND grade.종료일자 = "9999-01-01"
               JOIN tuning.사원 AS employee
                 ON admin.사원번호 = employee.사원번호
        ORDER  BY salary.연봉 DESC
        LIMIT  0, 5) AS 재직중인_상위_5위_연봉_관리자
       INNER JOIN (SELECT entrance.사원번호,
                          entrance.지역,
                          entrance.입출입구분,
                          entrance.입출입시간
                   FROM   tuning.사원출입기록 AS entrance
                   WHERE  entrance.입출입구분 = "o")AS record
               ON 재직중인_상위_5위_연봉_관리자.사원번호 =
                  record.사원번호;
```
#### 결과
* 0.423 sec / 0.000016 sec
* 0.440 sec / 0.000021 sec
* 0.381 sec / 0.000012 sec
* 0.390 sec / 0.000011 sec
* 0.396 sec / 0.000013 sec

#### 평균
* 5회 평균 - 0.406 sec

### INDEX 추가 
```sql
CREATE INDEX `idx_사원번호_이름` ON `tuning`.`사원출입기록` (사원번호);
```

#### 결과
* 0.0035 sec / 0.000034 sec
* 0.0032 sec / 0.000017 sec
* 0.0034 sec / 0.000015 sec
* 0.0030 sec / 0.000014 sec
* 0.0029 sec / 0.000011 sec

#### 평균
* 5회 평균 - 0.0032 sec

## B. 인덱스 설계

### * 실습환경 세팅

```sh
$ docker run -d -p 13306:3306 brainbackdoor/data-subway:0.0.2
```
- [workbench](https://www.mysql.com/products/workbench/)를 설치한 후 localhost:13306 (ID : root, PW : masterpw) 로 접속합니다.

<div style="line-height:1em"><br style="clear:both" ></div>

### * 요구사항

- [x] 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환

    - [x] [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.

    - [x] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)

    - [x] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

    - [x] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

    - [x] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

### 실습

### 1
```sql
SELECT hobby                                           AS CODING_AS_HOBBY,
       Count(hobby) * 100 / (SELECT Count(hobby)
                             FROM   subway.programmer) AS PERCANTAGE
FROM   subway.programmer
GROUP  BY hobby; 
```
#### 결과
* 0.505 sec / 0.000034 sec
* 0.504 sec / 0.0000081 sec
* 0.498 sec / 0.0000091 sec
* 0.529 sec / 0.0000079 sec
* 0.521 sec / 0.0000081 sec


#### 평균
* 5회 평균 - 0.511 sec

### INDEX 추가
```sql
CREATE INDEX `idx_hobby`  ON `subway`.`programmer` (hobby);
```

#### 결과
* 0.074 sec / 0.0000081 sec
* 0.076 sec / 0.0000079 sec
* 0.092 sec / 0.000012 sec
* 0.077 sec / 0.000013 sec
* 0.086 sec / 0.000013 sec

#### 평균
* 5회 평균 - 0.081 sec

### 2
```sql
SELECT c.programmer_id, h.name AS "병원 이름"
FROM (
    select id, programmer_id, hospital_id from subway.covid where programmer_id is not null
) as c
    INNER JOIN subway.hospital as h
    ON c.hospital_id = h.id;
```
#### 결과
* 0.0041 sec / 0.000085 sec
* 0.0041 sec / 0.00013 sec
* 0.0041 sec / 0.000041 sec
* 0.0046 sec / 0.000065 sec
* 0.0043 sec / 0.000041 sec

#### 평균
* 5회 평균 - 0.00424 sec

### 3
```sql
SELECT p.id AS programmer_id,
       c.id AS covid_id,
       h.name,
       p.hobby,
       p.dev_type,
       p.years_coding
FROM   subway.programmer p
         JOIN subway.covid c
              ON p.id = c.programmer_id
                AND ( ( p.hobby = "yes"
                  AND p.dev_type = "student" )
                  OR p.years_coding = "0-2 years" )
         JOIN subway.hospital AS h
              ON c.hospital_id = h.id;
```

#### 결과
* 5회 모두 30초 초과...

### INDEX 추가
```sql
CREATE INDEX `idx_pid_hid` ON `subway`.`covid` (programmer_id, hospital_id);
```

#### 결과
* 0.021 sec / 0.011 sec
* 0.021 sec / 0.015 sec
* 0.024 sec / 0.014 sec
* 0.022 sec / 0.012 sec
* 0.024 sec / 0.012 sec

#### 평균
* 5회 평균 - 0.022 sec

### 4
```sql
SELECT
  c.stay,
  count(c.programmer_id) as stay_count
FROM subway.covid c
       INNER JOIN subway.programmer p
                  ON c.programmer_id=p.id and p.country = "India"
       INNER JOIN subway.member m
                  ON c.member_id = m.id and m.age between 20 and 29
       INNER JOIN subway.hospital as h
                  ON c.hospital_id = h.id and h.name = "서울대병원"
GROUP BY c.stay;
```

#### 결과
* 5회 모두 30초 초과...

### INDEX 추가
```sql
CREATE INDEX `idx_pid_country` ON `subway`.`programmer` (id, country);
CREATE INDEX `idx_cid_stay` ON `subway`.`covid` (hospital_id, member_id, programmer_id, stay);
```

#### 결과
* 0.021 sec / 0.000027 sec
* 0.023 sec / 0.0000091 sec
* 0.022 sec / 0.000010 sec
* 0.025 sec / 0.000010 sec
* 0.023 sec / 0.0000091 sec



### 5
```sql
SELECT p.exercise,
       Count(p.id) AS exercise_count
FROM   subway.programmer p
         INNER JOIN subway.covid c
                    ON p.id = c.programmer_id
         INNER JOIN subway.member m
                    ON c.member_id = m.id
                      AND m.age BETWEEN 30 AND 39
         INNER JOIN subway.hospital AS h
                    ON c.hospital_id = h.id
                      AND h.name = "서울대병원"
GROUP  BY p.exercise; 
```

#### 결과
* 5회 모두 20초 초과...

### INDEX 추가
```sql
CREATE INDEX `idx_pid_country` ON `subway`.`programmer` (id, exercise(255));
CREATE INDEX `idx_cid_stay` ON `subway`.`covid` (hospital_id, member_id, programmer_id);
```

#### 결과
0.057 sec / 0.0000079 sec

0.067 sec / 0.0000088 sec

0.054 sec / 0.000013 sec

0.045 sec / 0.0000069 sec

0.051 sec / 0.000014 sec

#### 평균
* 5회 평균 - 0.0548 sec


## C. 프로젝트 요구사항

### a. 페이징 쿼리를 적용 

### b. Replication 적용 
