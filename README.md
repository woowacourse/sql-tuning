# 🚀 조회 성능 개선하기

## A. 쿼리 연습
<details>
<summary>실습환경 세팅</summary>
<div markdown="1">

```sh
$ docker run -d -p 23306:3306 brainbackdoor/data-tuning:0.0.1
```
- [workbench](https://www.mysql.com/products/workbench/)를 설치한 후 localhost:23306 (ID : user, PW : password) 로 접속합니다.

<div style="line-height:1em"><br style="clear:both" ></div>

> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)


<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

</div>
</details>

---
## A. 미션수행 내용 (실습 측정 환경 : 맥, 인텔칩)
```sql
SELECT a.사원번호, a.이름, a.연봉, a.직급명, 사원출입기록.입출입시간, 사원출입기록.지역, 사원출입기록.입출입구분
FROM ( SELECT 사원.사원번호, 사원.이름, 직급.직급명, 급여.연봉
	from 부서
	join 부서관리자 on 부서.부서번호 = 부서관리자.부서번호 and lower(부서.비고) = 'active'
	join 사원 on 부서관리자.사원번호 = 사원.사원번호 and 부서관리자.종료일자 = '9999-01-01' 	
	join 직급 on 사원.사원번호 = 직급.사원번호 and 직급.종료일자 = '9999-01-01' 
	join 급여 on 사원.사원번호 = 급여.사원번호 and 급여.종료일자 = '9999-01-01'
    ORDER BY 급여.연봉 desc
	limit 0, 5 ) AS a
JOIN 사원출입기록
ON 사원출입기록.사원번호 = a.사원번호 and 사원출입기록.입출입구분 = 'O'
ORDER BY a.연봉 DESC
```

### 인덱스 안 걸었을 시 
![image](https://user-images.githubusercontent.com/66905013/137458933-337ddde0-dc71-4197-a79f-777d0804d54e.png)

### 인덱스 설정(사원출입기록.사원번호)
![image](https://user-images.githubusercontent.com/66905013/137459067-ce586b5b-0c8b-45c9-bb99-a179e6a4093b.png)

---
## B. 인덱스 설계

<details>
<summary>실습환경 세팅</summary>
<div markdown="2">

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

</div>
</details>

---

## B. 미션수행 내용 (실습 측정 환경 : 윈도우)
## B-1
- [x] [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.

#### programmer 테이블
- pk 설정
- hobby 에 인덱스 설정

```sql
use subway;

# programmer 테이블에 pk 설정
ALTER TABLE `subway`.`programmer` 
CHANGE COLUMN `id` `id` BIGINT(20) NOT NULL AUTO_INCREMENT ,
ADD PRIMARY KEY (`id`),
ADD UNIQUE INDEX `id_UNIQUE` (`id` ASC);
;

# programmer.hobby에 index 설정
ALTER TABLE `subway`.`programmer` 
ADD INDEX `I_hobby` (`hobby` ASC);
;

# 쿼리
select hobby, round(count(*)/(select count(*) from programmer) * 100, 1) as percentage
from programmer
group by hobby
order by hobby desc;
```
![subway-b-1](https://user-images.githubusercontent.com/66905013/137607325-3112a670-e499-4ab8-a75e-38a4b052376b.PNG)

![subway-b-1-explain](https://user-images.githubusercontent.com/66905013/137607327-254bc71f-b75b-4ba8-9497-860f594a409f.png)

## B-2

- [x] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)

#### covid 테이블
- pk 설정
- `programmer_id`, `hospital_id` index 설정
#### hospital 테이블
- pk 설정

```sql
# covid pk 설정
ALTER TABLE `subway`.`covid` 
CHANGE COLUMN `id` `id` BIGINT(20) NOT NULL AUTO_INCREMENT ,
ADD PRIMARY KEY (`id`),
ADD UNIQUE INDEX `id_UNIQUE` (`id` ASC);

# hospital pk 설정
ALTER TABLE `subway`.`hospital` 
CHANGE COLUMN `id` `id` INT(11) NOT NULL AUTO_INCREMENT ,
ADD PRIMARY KEY (`id`),
ADD UNIQUE INDEX `id_UNIQUE` (`id` ASC);

# covid programmer_id, hospital_id index 설정
ALTER TABLE `subway`.`covid` 
ADD INDEX `I_programmer_id` (`programmer_id` ASC),
ADD INDEX `I_hospital_id` (`hospital_id` ASC);
;

# 쿼리
select p.id as programmer_id, c.id as covid_id, h.name
from programmer p
left join covid c
on p.id = c.programmer_id
left join hospital h
on h.id = c.hospital_id;
```
![subway-b-2](https://user-images.githubusercontent.com/66905013/137607416-ff097ed3-eb92-435d-9336-38fac468fff1.PNG)

![subway-b-2-explain](https://user-images.githubusercontent.com/66905013/137607423-a0c05724-d541-4d46-900a-d2329cdf76c7.png)

## B-3

- [x] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

#### member 테이블
- pk 에 unique 설정 추가

#### programmer 테이블
- hobby 인덱스를 (hobby, student) 복합인덱스로 변경
- years_coding 인덱스 추가

```sql
# member pk에 unique 설정 추가
ALTER TABLE `subway`.`member` 
ADD UNIQUE INDEX `id_UNIQUE` (`id` ASC);

# programmer hobby 인덱스를 (1. hobby, 2. student) 복합 인덱스로 변경
# programmer years_coding 인덱스 추가
ALTER TABLE `subway`.`programmer` 
DROP INDEX `I_hobby` ,
ADD INDEX `I_hobby__student` (`hobby` ASC, `student` ASC),
ADD INDEX `I_yearscoding` (`years_coding` ASC);

# 쿼리
select p.id, h.name
from (select id
	from programmer
    	where (hobby = 'Yes' and student = 'Yes') or years_coding = '0-2 years') as p
left join covid c
on c.programmer_id = p.id
left join hospital h
on h.id = c.hospital_id;
```

![subway-b-3](https://user-images.githubusercontent.com/66905013/137607508-d9eebfcf-8d0f-4521-84e5-7ed85cfdcaa1.PNG)

![subway-b-3-explain](https://user-images.githubusercontent.com/66905013/137607511-c0a8ed7a-1854-4630-b9fe-f91613adef4d.png)

## B-4

- [x] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

#### hospital 테이블
- name `text` -> `varchar(255)` 타입 변경
- name 인덱스 추가

#### member 테이블
- age 인덱스 추가

```sql
# hospital 에 name 타입변경 및 인덱스 추가
ALTER TABLE `subway`.`hospital` 
CHANGE COLUMN `name` `name` VARCHAR(255) NULL DEFAULT NULL ,
ADD INDEX `I_name` (`name` ASC);

# member 에 age 인덱스 추가
ALTER TABLE `subway`.`member` 
ADD INDEX `I_age` (`age` ASC);

# 쿼리
select count(*) as numberOfMember, c.stay
from (select id, name
	from hospital
    where name = '서울대병원') as h
join covid c
on h.id = c.hospital_id
join (select id
	from member
    where 20 <= age and age <30 ) as m
on c.member_id = m.id
join (select id
	from programmer
    where country = 'India') as p
on c.programmer_id = p.id
group by c.stay 
order by null;
```

![subway-b-4](https://user-images.githubusercontent.com/66905013/137607540-94a1eba7-e5d0-4ed9-a3c6-c279d18b6f9f.PNG)

![subway-b-4-explain](https://user-images.githubusercontent.com/66905013/137607541-2e2dfdbc-5462-4c01-b589-7822c73282d5.png)

## B-5

- [x] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

```sql
# 쿼리
select count(*), p.exercise
from (select id
	from hospital
    where name = '서울대병원') as h
join covid c
on c.hospital_id = h.id 
join (select id
	from member
    where 30 <= age and age < 40) as m
on m.id = c.member_id
join programmer p
on p.id = c.programmer_id
group by p.exercise
order by null;
```
![subway-b-5](https://user-images.githubusercontent.com/66905013/137607555-9121ebbf-aa21-4672-bf5e-8b4b04a70254.PNG)

![subway-b-5-explain](https://user-images.githubusercontent.com/66905013/137607562-5d6a5177-bad9-4afd-bfbc-e069b232e510.png)


---
## C. 프로젝트 요구사항

### a. 페이징 쿼리를 적용 

### b. Replication 적용 
