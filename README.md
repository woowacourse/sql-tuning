# 🚀 조회 성능 개선하기

# A. 쿼리 연습
> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)

## 인덱스 설정 전

### 쿼리 작성

```sql
SELECT top5.사원번호,
       사원.이름,
       top5.연봉,
       직급.직급명,
       사원출입기록.입출입시간,
       사원출입기록.지역,
       사원출입기록.입출입구분
FROM   사원
         INNER JOIN (SELECT 부서사원_매핑.사원번호,
                            급여.연봉
                     FROM   부서사원_매핑
                              INNER JOIN 부서관리자
                                         ON 부서관리자.사원번호 =
                                            부서사원_매핑.사원번호
                                           AND 부서관리자.부서번호 =
                                               부서사원_매핑.부서번호
                              INNER JOIN 부서
                                         ON 부서.부서번호 =
                                            부서사원_매핑.부서번호
                              INNER JOIN 급여
                                         ON 급여.사원번호 =
                                            부서사원_매핑.사원번호
                     WHERE  부서.비고 = 'active'
                       AND 부서관리자.종료일자 = '9999-01-01'
                       AND 부서사원_매핑.종료일자 = '9999-01-01'
                       AND 급여.종료일자 = '9999-01-01'
                     ORDER  BY 급여.연봉 DESC
                     LIMIT  5) AS top5
                    ON 사원.사원번호 = top5.사원번호
         INNER JOIN 직급
                    ON 직급.사원번호 = top5.사원번호
         INNER JOIN 사원출입기록
                    ON 사원출입기록.사원번호 = top5.사원번호
WHERE  직급.종료일자 = '9999-01-01'
  AND 입출입구분 = 'O'
ORDER  BY top5.연봉 DESC; 
```

### 쿼리 결과
![1](https://user-images.githubusercontent.com/56301069/137698165-a96d0c22-f7d4-4ab7-af58-8e1443efa5f8.png)

### 시간
![2](https://user-images.githubusercontent.com/56301069/137698170-fbd6521c-07a8-4bcf-ab97-a17900a45005.png)

### Visual Explain
![3](https://user-images.githubusercontent.com/56301069/137698173-34326c53-e0e2-4d4b-bda0-56ca79742131.png)

## 인덱스 설정 후
Visual Explain 확인 결과 `부서`와 `사원출입기록`에서 `Full Table Scan` 을 하므로, 이 둘 테이블에 대한 인덱스를 설정합니다.

```sql
CREATE INDEX `사원출입기록_인덱스` ON `tuning`.`사원출입기록` (사원번호);
CREATE INDEX `부서_인덱스` ON `tuning`.`부서` (부서번호, 비고);
```

### 시간
![4](https://user-images.githubusercontent.com/56301069/137698176-0869576b-f103-4f26-84cd-07a0ce689900.png)

### Visaul Explain
![5](https://user-images.githubusercontent.com/56301069/137698178-0c7ad940-d8a5-4438-aed3-88dffa985c1f.png)

# B. 인덱스 설계

## 요구사항
- 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환

## 1. Coding as a Hobby 와 같은 결과를 반환하세요.

### 쿼리 작성

```sql
SELECT hobby,
       ROUND(COUNT(hobby) / (SELECT COUNT(hobby) FROM programmer) * 100, 1) AS ratio FROM programmer 
GROUP BY hobby
ORDER BY ratio DESC;

CREATE INDEX `programmer_index` ON programmer (hobby);
```

### 쿼리 결과
![6](https://user-images.githubusercontent.com/56301069/137698180-a3290365-71ce-4837-968c-5d6027216a4e.png)

### 시간
![7](https://user-images.githubusercontent.com/56301069/137698181-5bbcd959-2f01-49b6-8d8e-3338e044a9f8.png)

## 2. 프로그래머별로 해당하는 병원 이름을 반환하세요. (covid.id, hospital.name)

### 쿼리 작성

```sql
SELECT covid.id,
       hospital.name
FROM   covid
         LEFT OUTER JOIN hospital
                         ON hospital.id = covid.hospital_id
WHERE  covid.programmer_id IS NOT NULL;

CREATE INDEX `covid_index` ON covid (hospital_id); 
```

### 쿼리 결과
![8](https://user-images.githubusercontent.com/56301069/137698185-644e5a5b-2027-490a-9243-aa6c47477b1b.png)

### 시간
![9](https://user-images.githubusercontent.com/56301069/137698186-d811f3f0-54d3-4fa5-b7c3-c8f347a2a9af.png)

### Visual Explain
![10](https://user-images.githubusercontent.com/56301069/137698188-432b8581-55f2-48fa-99c4-3d6112e695b0.png)

## 3. 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

### 쿼리 작성

```sql
SELECT covid.id,
       hospital.name,
       user.hobby,
       user.devtype,
       user.yearscoding
FROM   covid
         INNER JOIN hospital
                    ON covid.hospital_id = hospital.id
         INNER JOIN (SELECT id,
                            hobby,
                            dev_type     AS DevType,
                            years_coding AS YearsCoding
                     FROM   programmer
                     WHERE  ( hobby = 'yes'
                       AND student LIKE( 'yes%' ) )
                        OR years_coding = '0-2 years') AS `user`
                    ON covid.programmer_id = user.id
WHERE  covid.programmer_id IS NOT NULL
ORDER  BY user.id ASC;

CREATE INDEX `covid_index` ON covid (programmer_id); 
```

### 쿼리 결과
![11](https://user-images.githubusercontent.com/56301069/137698190-e61e8010-c2d4-4d12-ac87-ca1b9a7d5598.png)

### 시간
![12](https://user-images.githubusercontent.com/56301069/137698192-94d32035-5235-4df9-a492-d8344e95731f.png)

### Visual Explain
![13](https://user-images.githubusercontent.com/56301069/137698196-c3c6341e-07f4-4d30-91d3-bba731d201bd.png)

## 4. 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

### 쿼리 작성

```sql
SELECT covid.stay,
       Count(covid.stay) AS total
FROM   covid
         INNER JOIN (SELECT id
                     FROM   hospital
                     WHERE  name = '서울대병원') AS seoul
                    ON covid.hospital_id = seoul.id
         INNER JOIN (SELECT id,
                            age
                     FROM   member
                     WHERE  age BETWEEN 20 AND 29) AS age
                    ON covid.member_id = age.id
         INNER JOIN (SELECT id,
                            country
                     FROM   programmer
                     WHERE  country = 'india') AS country
                    ON covid.programmer_id = country.id
GROUP  BY covid.stay;

CREATE INDEX `hospital_index` ON hospital (name);

CREATE INDEX `programmer_index` ON programmer (id);

CREATE INDEX `covid_index` ON covid (hospital_id, programmer_id, member_id, stay
  ); 
```

### 쿼리 결과
![14](https://user-images.githubusercontent.com/56301069/137698198-bd3b8c6d-6f6c-4ea7-a587-f33d2b7eb2d9.png)

### 시간
![15](https://user-images.githubusercontent.com/56301069/137698201-3bfac8b0-7624-4593-9b62-9a8859bef604.png)

### Visual Explain
![16](https://user-images.githubusercontent.com/56301069/137698202-c99ae04f-8aa2-46c7-87cd-bd16960afc7e.png)

## 5. 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)
### 쿼리 작성

```sql
SELECT programmer.exercise,
       Count(programmer.exercise) AS total
FROM   covid
         INNER JOIN (SELECT id
                     FROM   hospital
                     WHERE  NAME = '서울대병원') AS seoul
                    ON covid.hospital_id = seoul.id
         INNER JOIN (SELECT id,
                            age
                     FROM   member
                     WHERE  age BETWEEN 30 AND 39) AS age
                    ON covid.member_id = age.id
         INNER JOIN programmer
                    ON covid.programmer_id = programmer.id
GROUP  BY programmer.exercise;

CREATE INDEX `hospital_index` ON hospital (name);
CREATE INDEX `programmer_index` ON programmer (id);
CREATE INDEX `covid_index` ON covid (hospital_id, programmer_id, member_id);
```

### 쿼리 결과
![17](https://user-images.githubusercontent.com/56301069/137698203-9d85b24a-2c3e-4282-b3fa-9574df4ad9e0.png)

### 시간
![18](https://user-images.githubusercontent.com/56301069/137698204-872f64dd-b1ce-46d1-b598-169fe8cae63f.png)

### Visual Explain
![19](https://user-images.githubusercontent.com/56301069/137698207-4401f20b-92a1-47ef-bf5b-b5d3ae49545b.png)
