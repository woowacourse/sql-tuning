# A. 쿼리 연습

- [x] 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)

1. 쿼리 작성만으로 1s 이하로 반환한다.

__쿼리문__

```sql
select 부서관리자_급여.사원번호, 부서관리자_급여.이름, 부서관리자_급여.연봉, 부서관리자_급여.직급명, 사원출입기록.입출입시간, 사원출입기록.지역, 사원출입기록.입출입구분
from (select 부서관리자.사원번호, 사원.이름, 급여.연봉, 직급.직급명
    from 부서관리자
    Left Join 급여 ON 부서관리자.사원번호 = 급여.사원번호
    Left Join 사원 ON 부서관리자.사원번호 = 사원.사원번호
    Left Join 직급 ON 부서관리자.사원번호 = 직급.사원번호
    Left Join 부서 ON 부서관리자.부서번호 = 부서.부서번호
    where lower(부서.비고) = 'active' and 부서관리자.종료일자 = '9999-01-01' and 급여.종료일자 = '9999-01-01' and 직급.종료일자 = '9999-01-01'
    order by 급여.연봉 desc limit 5
    ) AS 부서관리자_급여
    left join 사원출입기록 ON 부서관리자_급여.사원번호 = 사원출입기록.사원번호
where 사원출입기록.입출입구분 = 'O'
order by 부서관리자_급여.연봉 desc;
```

__실행 계획__

<img width="1052" alt="스크린샷 2021-10-14 오후 7 41 57" src="https://user-images.githubusercontent.com/63405904/137302458-7520bb22-9617-4f18-bf71-455dc65a42cb.png">

__결과 테이블__

<img width="426" alt="스크린샷 2021-10-14 오후 7 43 32" src="https://user-images.githubusercontent.com/63405904/137302673-85bec4dc-83ba-479c-a37b-800613c8d3d0.png">

__시간 측정__

<img width="1435" alt="스크린샷 2021-10-14 오후 7 43 57" src="https://user-images.githubusercontent.com/63405904/137302725-37e3f826-9700-4615-9e6f-5dc610e58ca9.png">

<br>

2. 인덱스 설정을 추가하여 50 ms 이하로 반환한다.

__인덱스 설정__

```sql
CREATE INDEX `idx_사원_입출입시간`  ON `tuning`.`사원출입기록` (사원번호);
CREATE INDEX `idx_부서관리자_종료일자`  ON `tuning`.`부서관리자` (종료일자);
```

__실행 계획__

<img width="1106" alt="스크린샷 2021-10-14 오후 7 52 12" src="https://user-images.githubusercontent.com/63405904/137303948-73ee157f-66f5-49cb-8bd7-17c9f8997102.png">

__시간 측정__

<img width="1169" alt="스크린샷 2021-10-14 오후 7 56 38" src="https://user-images.githubusercontent.com/63405904/137304522-57b2f8c9-26a0-4c8b-854f-fed8183e94d9.png">

- 최종시간 : 0.0075 sec

<br>

# B. 인덱스 설계

## 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환

### 1번 

- [x] Coding as a Hobby 와 같은 결과를 반환하세요.

__쿼리문__

```sql
select 
round((select count(*) from programmer where hobby='Yes') / count(*) * 100, 2) as yes,
round((select count(*) from programmer where hobby='No') / count(*) * 100, 2) as no
from subway.programmer;
```

1. 인덱스 적용 전 

__결과 테이블__

<img width="190" alt="스크린샷 2021-10-14 오후 8 01 33" src="https://user-images.githubusercontent.com/63405904/137305250-804cf4ed-bca3-4ad1-85f8-137a05bfa0de.png">

__실행 계획__

<img width="469" alt="스크린샷 2021-10-14 오후 8 01 52" src="https://user-images.githubusercontent.com/63405904/137305312-d76bef3e-d287-4639-a05a-a62ef4657ed9.png">

__시간 측정__

<img width="1171" alt="스크린샷 2021-10-14 오후 8 02 21" src="https://user-images.githubusercontent.com/63405904/137305389-bb58e950-8565-44a5-b9b7-f82987eb6a1c.png">

- 시간 : 0.936 sec

2. 인덱스 적용 후 

__인덱스 설정__
```sql
ALTER TABLE `subway`.`programmer` 
CHANGE COLUMN `id` `id` BIGINT(20) NOT NULL ,
ADD PRIMARY KEY (`id`);

CREATE INDEX idx_hobby ON programmer(hobby);
```

__실행 계획__

<img width="562" alt="스크린샷 2021-10-14 오후 8 06 09" src="https://user-images.githubusercontent.com/63405904/137305965-4297a706-093d-4eef-a34f-b31afc93633f.png">

__시간 측정__

<img width="1174" alt="스크린샷 2021-10-14 오후 8 07 08" src="https://user-images.githubusercontent.com/63405904/137306113-8e636eb1-afbf-497d-bb92-ee41c732bf79.png">

- 시간 : 0.048 sec 

<br>

### 2번 

- [x] 프로그래머별로 해당하는 병원 이름을 반환하세요. (programmer.id, hospital.name)

__쿼리문__

```sql
select programmer_id, hospital.name
from (select programmer_id, hospital_id from covid where programmer_id is not null) programmer_covid 
inner join hospital on programmer_covid.hospital_id = hospital.id; 
```

1. 인덱스 적용 전 

__결과 테이블__

<img width="164" alt="스크린샷 2021-10-14 오후 8 21 46" src="https://user-images.githubusercontent.com/63405904/137308109-b7d4e921-a108-4f17-9e90-0a46fc2b554d.png">

__실행 계획__

<img width="312" alt="스크린샷 2021-10-14 오후 8 25 50" src="https://user-images.githubusercontent.com/63405904/137308617-35c367ce-b2a7-4b7d-bab8-8a6ea8e7ff87.png">

__시간 측정__

<img width="396" alt="스크린샷 2021-10-14 오후 8 27 30" src="https://user-images.githubusercontent.com/63405904/137308869-6d3ed776-132a-42f4-bb09-a681c053ceca.png">

- 시간 : 0.019 sec 

2. 인덱스 적용 후 

__인덱스 설정__

```sql
ALTER TABLE `subway`.`hospital` 
CHANGE COLUMN `id` `id` INT(11) NOT NULL ,
ADD PRIMARY KEY (`id`);

ALTER TABLE `subway`.`hospital` 
CHANGE COLUMN `name` `name` VARCHAR(255) NULL DEFAULT NULL ,
ADD UNIQUE INDEX `name_UNIQUE` (`name` ASC);

CREATE INDEX idx_covid_hospital ON covid(hospital_id);
```

__실행 계획__

<img width="361" alt="스크린샷 2021-10-14 오후 8 23 40" src="https://user-images.githubusercontent.com/63405904/137308311-35272ec8-4db0-4670-9b41-0bf26f360de0.png">

__시간 측정__

<img width="412" alt="스크린샷 2021-10-14 오후 8 22 01" src="https://user-images.githubusercontent.com/63405904/137308132-144fa577-2996-408f-b5c3-2458e6cda779.png">

- 시간 : 0.018 sec 

<br>

### 3번 

- [x] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

__쿼리문__

```sql
select covid.id, hospital.name, programmer.hobby, programmer.dev_type, programmer.years_coding
from covid 
inner join programmer on covid.programmer_id = programmer.id
inner join hospital on hospital.id = covid.hospital_id
where hobby = 'Yes' and (student = 'Yes, part-time' or student = 'Yes, full-time' or years_coding = '0-2 years')
order by programmer.id;
```

1. 인덱스 적용 전 

__결과 테이블__

![스크린샷 2021-10-15 오전 9 49 32](https://user-images.githubusercontent.com/63405904/137414913-1008e399-ec08-4e30-94f4-8cb16c968bd0.png)

__실행 계획__

<img width="463" alt="스크린샷 2021-10-14 오후 8 31 47" src="https://user-images.githubusercontent.com/63405904/137309499-9e40498f-aa37-4c45-afb6-4dbc41b33004.png">

__시간 측정__

![스크린샷 2021-10-15 오전 9 47 09](https://user-images.githubusercontent.com/63405904/137414927-a1ad93a4-0ab6-4e41-b1a6-71c754dea1a6.png)

- 시간 : 3.003 sec timeout 

2. 인덱스 적용 후 

__인덱스 설정__

```sql
ALTER TABLE `subway`.`programmer` 
CHANGE COLUMN `id` `id` BIGINT(20) NOT NULL ,
ADD PRIMARY KEY (`id`);

ALTER TABLE `subway`.`hospital` 
CHANGE COLUMN `id` `id` INT(11) NOT NULL ,
CHANGE COLUMN `name` `name` VARCHAR(255) NULL DEFAULT NULL ,
ADD PRIMARY KEY (`id`),
ADD UNIQUE INDEX `name_UNIQUE` (`name` ASC);;


CREATE INDEX idx_covid_programmer_id ON covid(programmer_id);
CREATE INDEX idx_hobby ON programmer(hobby);
```

__실행 계획__

![스크린샷 2021-10-15 오전 9 55 54](https://user-images.githubusercontent.com/63405904/137415347-cd4978b2-8e15-49da-bff1-99461e8ec368.png)

__시간 측정__

![스크린샷 2021-10-15 오전 9 56 18](https://user-images.githubusercontent.com/63405904/137415374-fb27fc7a-8308-453e-aaa6-5b341bdf3bd0.png)

- 시간 : 0.027 sec 

<br>

### 4번

- [x] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

__쿼리문__

```sql
select covid.stay, count(*)
from programmer 
    inner join (select id from member where age between 20 and 29) twenty_member 
    on programmer.id = twenty_member.id
    inner join covid 
    on covid.member_id = programmer.id
    inner join (select id from hospital where name = '서울대병원') selected_hospital 
    on selected_hospital.id = covid.hospital_id
where programmer.country = 'India'
group by covid.stay
order by null;
```

1. 인덱스 적용 전 

__결과 테이블__

![스크린샷 2021-10-15 오전 9 58 48](https://user-images.githubusercontent.com/63405904/137415564-3fcf723c-d496-4796-af92-e96f78fb490d.png)

__실행 계획__

![스크린샷 2021-10-15 오전 9 59 15](https://user-images.githubusercontent.com/63405904/137415587-caef556b-bffe-4317-bbc6-5d91466b02f7.png)

__시간 측정__

![스크린샷 2021-10-15 오전 9 59 42](https://user-images.githubusercontent.com/63405904/137415619-1bc7edbb-63eb-4f8b-91b9-552bc6974dbe.png)

- 시간 : 0.252 sec 

2. 인덱스 적용 후 

__인덱스 설정__

```sql
ALTER TABLE `subway`.`programmer` 
CHANGE COLUMN `id` `id` BIGINT(20) NOT NULL ,
ADD PRIMARY KEY (`id`);

ALTER TABLE `subway`.`member` 
CHANGE COLUMN `id` `id` BIGINT(20) NOT NULL ,
ADD PRIMARY KEY (`id`);

ALTER TABLE `subway`.`hospital` 
CHANGE COLUMN `id` `id` INT(11) NOT NULL ,
CHANGE COLUMN `name` `name` VARCHAR(255) NULL DEFAULT NULL ,
ADD PRIMARY KEY (`id`),
ADD UNIQUE INDEX `name_UNIQUE` (`name` ASC);;

CREATE INDEX idx_covid_hospital_id ON covid(hospital_id);
CREATE INDEX idx_covid_member_id ON covid(member_id);
CREATE INDEX idx_covid_stay ON covid(stay);
CREATE INDEX idx_member_age ON member(age);
```

__실행 계획__

![스크린샷 2021-10-15 오전 10 11 08](https://user-images.githubusercontent.com/63405904/137416392-92b1868b-0b9f-45ae-a582-7f234e5d69f7.png)

__시간 측정__

![스크린샷 2021-10-15 오전 10 11 31](https://user-images.githubusercontent.com/63405904/137416419-4bf0212c-7d27-4f7e-8d4d-98a29e264b12.png)

- 시간 : 0.058 sec 

<br>

### 5번

- [x] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

__쿼리문__

```sql
select exercise, count(*)
from member
inner join(select id, exercise from programmer) as programmer on programmer.id = member.id
inner join covid on covid.member_id = programmer.id
inner join (select id from hospital where name = '서울대병원') selected_hospital on selected_hospital.id = covid.hospital_id
where age between 30 and 39
group by programmer.exercise
order by null;
```

1. 인덱스 적용 전 

__결과 테이블__

![스크린샷 2021-10-15 오전 10 13 11](https://user-images.githubusercontent.com/63405904/137416539-b97b9f13-abd1-4a4f-8822-1e334c5ef954.png)

__실행 계획__

- 4번과 동일

2. 인덱스 적용 후 

__인덱스 설정__

```sql
ALTER TABLE `subway`.`programmer` 
CHANGE COLUMN `id` `id` BIGINT(20) NOT NULL ,
ADD PRIMARY KEY (`id`);

ALTER TABLE `subway`.`member` 
CHANGE COLUMN `id` `id` BIGINT(20) NOT NULL ,
ADD PRIMARY KEY (`id`);

ALTER TABLE `subway`.`hospital` 
CHANGE COLUMN `id` `id` INT(11) NOT NULL ,
CHANGE COLUMN `name` `name` VARCHAR(255) NULL DEFAULT NULL ,
ADD PRIMARY KEY (`id`),
ADD UNIQUE INDEX `name_UNIQUE` (`name` ASC);

ALTER TABLE `subway`.`programmer` 
CHANGE COLUMN `exercise` `exercise` VARCHAR(255) NULL DEFAULT NULL;

CREATE INDEX idx_covid_hospital_id ON covid(hospital_id);
CREATE INDEX idx_programmer_exercise ON programmer(exercise);
CREATE INDEX idx_member_age ON member(age);
```

__실행 계획__

![스크린샷 2021-10-15 오전 10 23 59](https://user-images.githubusercontent.com/63405904/137417322-7943c595-7824-4dc1-942b-b5658bb0e25f.png)

__시간 측정__

![스크린샷 2021-10-15 오전 10 24 52](https://user-images.githubusercontent.com/63405904/137417377-423c0f0f-8604-4a39-a4b4-4d7531907306.png)

- 시간 : 0.080 sec 

<br>