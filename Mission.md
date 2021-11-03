# SQL 미션


## A. 쿼리 연습

> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)

### 1. 쿼리 작성만으로 1s 이하로 반환한다.

**쿼리**

```sql
SELECT 상위연봉사원.사원번호, 상위연봉사원.이름, 상위연봉사원.연봉, 상위연봉사원.직급명, 사원출입기록.입출입구분, 사원출입기록.입출입시간, 사원출입기록.지역
FROM 사원출입기록 
INNER JOIN (
	SELECT 사원.사원번호, 사원.이름, 급여.연봉, 직급.직급명
	FROM 사원 
	INNER JOIN 급여 ON 급여.사원번호 = 사원.사원번호
	INNER JOIN 직급 ON 직급.사원번호 = 사원.사원번호
	INNER JOIN 부서관리자 ON 직급.사원번호 = 부서관리자.사원번호
	INNER JOIN 부서 ON 부서관리자.부서번호 = 부서.부서번호
	WHERE 급여.종료일자 = "9999-01-01" AND 직급.종료일자 = "9999-01-01"
		AND LOWER(부서.비고) = "active" AND 부서관리자.종료일자 = "9999-01-01"
	ORDER BY 급여.연봉 DESC LIMIT 5
) 상위연봉사원 ON 사원출입기록.사원번호 = 상위연봉사원.사원번호
WHERE 사원출입기록.입출입구분 = "O"
ORDER BY 상위연봉사원.연봉 DESC, 사원출입기록.입출입시간 DESC;
```

**조회 결과**

![image](https://user-images.githubusercontent.com/43840561/137600146-8f535669-7889-4db3-a14c-0c39abdce3fc.png)

![image](https://user-images.githubusercontent.com/43840561/137600143-56e9df80-4138-43f4-ab0b-7dc14a375d4b.png)

**실행 계획** 

![image](https://user-images.githubusercontent.com/43840561/137600149-1809d26f-2361-4793-9d06-cd773ca8c840.png)
### 2. 인덱스 설정을 추가하여 50 ms 이하로 반환한다.

**인덱스 추가**

```sql
CREATE INDEX `IDX_사원번호_입출입구분` ON tuning.사원출입기록 (사원번호, 입출입구분);

```

- 조인 컬럼인 사원출입기록 테이블의 사원번호에 인덱스 생성
  - 한쪽에만 인덱스가 있을 경우, Join Buffer를 사용하여 성능 개선을 하나 일반적인 중첩 루프 조인에 비해 효율이 떨어지기 때문
  - 또한 테이블 크기와 상관없이 인덱스가 있는 테이블이 드라이빙 테이블이 되기 때문

**조회 결과**

![image](https://user-images.githubusercontent.com/43840561/137600153-1d74e1dc-f9cf-4c78-9346-3db7a5ab68a1.png)

**Duration**

![image](https://user-images.githubusercontent.com/43840561/137600159-ba0b19d5-3988-40be-afeb-bf88c3b5f9d2.png)

**실행 계획** 
**(사원번호)**
![image](https://user-images.githubusercontent.com/43840561/137600163-d8623b80-1415-47f0-8110-4715f41a922a.png)

**(사원번호, 입출입구분)**
![image](https://user-images.githubusercontent.com/43840561/139713135-e2dec952-0d6c-4980-b262-cd7b87c59150.png)


## B. 인덱스 설계

### 1. [Coding as a Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.

**쿼리**

```sql
SELECT 
ROUND(COUNT(CASE WHEN hobby = "Yes" THEN 1 END) / COUNT(*) * 100, 1) as Yes,
ROUND(COUNT(CASE WHEN hobby = "No"  THEN 1 END) / COUNT(*) * 100, 1) as No
FROM programmer;
```

**Duration**

![image](https://user-images.githubusercontent.com/43840561/137600191-3500461e-d271-432b-8ba7-0af958bae6a3.png)

#### pk 인덱스 추가

```sql
ALTER TABLE `subway`.`programmer` 
CHANGE COLUMN `id` `id` BIGINT(20) NOT NULL ,
ADD PRIMARY KEY (`id`);
```

- id에 pk를 추가함으로써 자동으로 index가 추가되었음

**Duration**

![image](https://user-images.githubusercontent.com/43840561/137600198-6a940a06-c41c-485a-abc0-610e20013f64.png)

#### 실행계획

![image](https://user-images.githubusercontent.com/43840561/137600206-6fc1660d-a1b7-4086-aff8-98fae943fce1.png)
![image](https://user-images.githubusercontent.com/43840561/137600209-81ab357d-9295-4700-a53f-0569dbbaa38d.png)

- 아직까지는 index를 사용하고 있지 않음

#### hobby에 인덱스 추가

```sql
ALTER TABLE `subway`.`programmer` 
ADD INDEX `idx_hobby` (`hobby`);
```

**Duration**

![image](https://user-images.githubusercontent.com/43840561/137600213-71ce92d3-144e-4a81-a6a2-55718aa87946.png)

**실행계획**

![image](https://user-images.githubusercontent.com/43840561/137600216-517057af-8bf1-4d16-9a26-64e6370ab1b1.png)
![image](https://user-images.githubusercontent.com/43840561/137600218-dceca613-6303-42ba-82fb-534bcfc8410c.png)

### 2. 프로그래머별로 해당하는 병원 이름을 반환하세요. (covid.id, hospital.name)

**처음 쿼리**

```sql
SELECT covid.programmer_id, hospital.name
FROM covid 
INNER JOIN hospital ON hospital.id = covid.hospital_id
WHERE covid.programmer_id is not null
GROUP BY covid.programmer_id, hospital.name;
```

**Duration**

![image](https://user-images.githubusercontent.com/43840561/137600229-4640732f-16ba-46fa-9725-1ebdad252341.png)

**실행계획**

![image](https://user-images.githubusercontent.com/43840561/137600232-e4a95b2c-c33f-469e-906f-2015cc600151.png)

**다시 짠** **쿼리**

```sql
SELECT covid.programmer_id, hospital.name
FROM covid 
JOIN programmer on programmer.id = covid.programmer_id
JOIN hospital ON covid.hospital_id = hospital.id;
```

**Duration**

![image](https://user-images.githubusercontent.com/43840561/137600237-be26e8f9-6269-48fc-abca-cad8f76baa8b.png)

**실행계획**

![image](https://user-images.githubusercontent.com/43840561/137600248-ef326953-6619-47e0-b852-603600c10ef9.png)

#### hospital과 covid에 pk 추가

```sql
ALTER TABLE `subway`.`hospital` 
CHANGE COLUMN `id` `id` INT(11) NOT NULL ,
ADD PRIMARY KEY (`id`);

ALTER TABLE `subway`.`covid` 
CHANGE COLUMN `id` `id` INT(11) NOT NULL ,
ADD PRIMARY KEY (`id`);
```

**실행계획**

![image](https://user-images.githubusercontent.com/43840561/137600253-dfd67479-8520-4be2-92a4-1e1ef507c03b.png)

#### covid 테이블에 programmer_id & hospital_id 인덱스 추가

```sql
ALTER TABLE `subway`.`covid` 
ADD INDEX `idx_programmer_id_hospital_id` (`programmer_id` ASC, `hospital_id` ASC);
```

**Duration**

![image](https://user-images.githubusercontent.com/43840561/137600260-80590902-ccb6-44a4-92c1-834d5309fd8e.png)

**실행계획**

![image](https://user-images.githubusercontent.com/43840561/137600267-d77b51b3-7bf3-4ee9-aee5-5bf4dfda160b.png)

### 3. 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, usercovid.Hobby, userprogrammer.DevType, user.YearsCoding)

**쿼리**

```sql
SELECT covid.id, hospital.name, programmer.Hobby, programmer.Dev_Type, programmer.Years_Coding
FROM (
	SELECT id, hobby, dev_type, years_coding, student 
    FROM programmer 
    WHERE (hobby = "Yes" and student != "NO" and student != "NA") or years_coding = "0-2 years"
    ) AS programmer
INNER JOIN covid ON covid.programmer_id = programmer.id
INNER JOIN hospital ON hospital.id = covid.hospital_id;
```

**Duration**

![image](https://user-images.githubusercontent.com/43840561/137600275-ca7a16db-22f1-4a3f-b3d9-ad771ce5cecb.png)

**실행계획**

![image](https://user-images.githubusercontent.com/43840561/137600283-bd3d5bb4-d648-4da5-980b-27d4535ccebc.png)

#### 인덱스 추가 사항 없음

- idx_hobby_student를 추가해보았지만 차이 없음

### 4. 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

**쿼리**

```sql
SELECT C.stay, count(*) 
FROM covid as C
INNER JOIN hospital H ON C.hospital_id = H.id
INNER JOIN programmer P ON C.programmer_id = P.id 
INNER JOIN member M ON C.member_id = M.id 
WHERE H.name = '서울대병원'  AND P.country = 'india' AND (age between 20 and 29)
group by C.stay;
```

**Duration**

![image](https://user-images.githubusercontent.com/43840561/137600293-2eccfc74-15f9-4940-84b5-abd1ffbc4a5d.png)

**실행계획**

![image](https://user-images.githubusercontent.com/43840561/137600302-8cc25cbf-32ed-4dbc-b30f-2c6d38f52199.png)

**인덱스 추가 - covid에 member_id, member에 age, hospital에 name**

```sql
ALTER TABLE `subway`.`member` 
ADD INDEX `idx_age` (`age` ASC);

ALTER TABLE `subway`.`hospital` 
CHANGE COLUMN `name` `name` VARCHAR(255) NULL DEFAULT NULL ,
ADD UNIQUE INDEX `name_UNIQUE` (`name` ASC);

ALTER TABLE `subway`.`covid` 
ADD INDEX `idx_programmer_id_hospital_id_member_id` (`hospital_id` ASC, `programmer_id` ASC, `member_id` ASC);
```

**Duration**
![image](https://user-images.githubusercontent.com/43840561/139710594-c1eb2dd6-efc0-40e5-9113-3b565035eb1f.png)

**실행 계획**

![image](https://user-images.githubusercontent.com/43840561/139709940-002078e4-82ff-4673-b2e7-b007bc1b45d1.png)

### 5. 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

**쿼리**

```sql
SELECT P.exercise, COUNT(M.id) 
FROM programmer P
    JOIN covid C ON P.id = C.programmer_id
    JOIN member M ON P.member_id = M.id
    JOIN hospital H ON C.hospital_id = H.id
WHERE (M.age >= 30 and M.age < 40) AND H.name = '서울대병원'
GROUP BY P.exercise;
```

**Duration**

![image](https://user-images.githubusercontent.com/43840561/137600323-5501fef0-b4e6-4b3e-8d38-eab79e396ee9.png)

**실행계획**

![image](https://user-images.githubusercontent.com/43840561/137600319-23f6770d-1963-4f1f-891d-a0e686942066.png)
