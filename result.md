# SQL Tuning

## 요구사항 1
- 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)
- 급여 테이블의 사용여부 필드는 사용하지 않습니다. 현재 근무중인지 여부는 종료일자 필드로 판단해주세요.
- 쿼리 작성만으로 1s 이하로 반환한다.
- 인덱스 설정을 추가하여 50 ms 이하로 반환한다. (0.05 sec)


```sql
select info.사원번호, info.이름, info.연봉, info.직급명, note.입출입시간, note.지역, note.입출입구분
from (
	select manager.사원번호, employee.이름, pay.연봉, rank.직급명
		from (
			select 사원번호, 시작일자, 종료일자
			from 부서, 부서관리자
			where 부서.비고 = 'active' and 부서.부서번호 = 부서관리자.부서번호
			and 부서관리자.시작일자 <= now() and 부서관리자.종료일자 >= now()
		) as manager
		inner join (select 사원번호, 이름 from 사원) as employee
		on manager.사원번호 = employee.사원번호
		inner join (select 사원번호, 연봉, 시작일자, 종료일자 from 급여) as pay
		on manager.사원번호 = pay.사원번호 and pay.시작일자 <= now() and pay.종료일자 >= now()
		inner join (select 사원번호, 직급명, 시작일자, 종료일자 from 직급) as rank
		on manager.사원번호 = rank.사원번호 and rank.시작일자 <= now() and rank.종료일자 >= now()
		order by pay.연봉 desc limit 5
) as info
    inner join (select 사원번호, 입출입시간, 입출입구분, 출입문, 지역 from 사원출입기록) as note
    on info.사원번호 = note.사원번호 and note.입출입구분 = 'O'
    order by info.연봉 desc;
```

![image](https://user-images.githubusercontent.com/34594339/137607083-6f0d9edb-037f-4bc5-8f7a-0f1606210360.png)
![image](https://user-images.githubusercontent.com/34594339/137607086-fc1fece8-2a09-4c9a-afd9-e23a60d190b0.png)

👉 duration : `0.250 sec`

#### 1. 사원번호와 입출입구분을 인덱싱

![image](https://user-images.githubusercontent.com/34594339/137607110-945d7e3c-389b-4193-bfe6-93975685c28e.png)

![image](https://user-images.githubusercontent.com/34594339/137607116-c838c4a0-3c6a-45b2-af31-b7d14d559073.png)

![image](https://user-images.githubusercontent.com/34594339/137607119-90485346-61d5-40f9-85fb-39f7ee1e29ad.png)

👉 duration : `0.015 sec` (m1 mac)

  
#### 2. 현재 쿼리문에 있는 모든 날짜 비교를 between으로 수정

![image](https://user-images.githubusercontent.com/34594339/137607137-904c37bd-d994-44c0-8ac9-1b906dfcb535.png)

👉 duration : `0.0077 sec` (m1 mac)

<br>
<br>
   
## 요구사항 2
- 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환 (0.1 sec)
  - [Coding as a Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.
  - 프로그래머별로 해당하는 병원 이름을 반환하세요. (covid.id, hospital.name)
  - 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)
  - 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)
  - 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)


## Coding as a Hobby 와 같은 결과를 반환하세요.

### SQL Query

```SQL
select
	round(count(case when hobby = 'yes' then 1 end) / count(*) * 100, 1) as 'yes',
    round(count(case when hobby = 'no' then 1 end) / count(*)  * 100, 1) as 'no'
    from programmer;
```

![image](https://user-images.githubusercontent.com/34594339/137607204-93892400-d82d-4c0f-9040-1f6e543f45c1.png)

👉 duration : `0.0141 sec` (win)

<br>

#### hobby에 인덱싱

![image](https://user-images.githubusercontent.com/34594339/137607231-9ca979f7-958c-4822-8c06-e848e72813c0.png)

👉 duration : `0.031 sec` (win)

<br>

## 프로그래머별로 해당하는 병원 이름을 반환하세요. (covid.id, hospital.name)

```SQL
select covid.id, programmer_id, hospital_id, h.name
from covid
	inner join (select * from hospital) as h
	on h.id = covid.hospital_id
where programmer_id is not null;
```

![image](https://user-images.githubusercontent.com/34594339/137607255-83d85821-9b7c-4771-89e5-a00f70337da1.png)

![image](https://user-images.githubusercontent.com/34594339/137607258-3205d8c2-e2df-42f0-8400-0b4e8e110c23.png)

![image](https://user-images.githubusercontent.com/34594339/137607262-47981a14-c2c2-4064-91b0-2a3e336979ab.png)

👉 duration : `0.033sec` (m1 mac)

<br>

#### covid 테이블의 id 인덱싱 (unique 제약), hospital_id 인덱싱 & covid 테이블의 id 인덱싱 (unique 제약)

![image](https://user-images.githubusercontent.com/34594339/137607292-7dfa6ea6-076d-4715-ad9e-c4f136ec6576.png)
![image](https://user-images.githubusercontent.com/34594339/137607296-48e7c968-9e26-452f-99da-93fb92cdb367.png)
![image](https://user-images.githubusercontent.com/34594339/137607299-3a83aadb-50b5-4fe3-950b-a85f8154bbb5.png)

👉 duration : `0.018sec` (m1 mac)

<br>

## 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

```SQL
select c.c_id, c.name, hobby, dev_type, years_coding
from programmer as p
	inner join (
		select id as c_id, programmer_id, h.*
        from covid
        inner join (select id as h_id, name  from hospital) as h
				on h.h_id = hospital_id
    ) as c
    on p.id = c.programmer_id
where (hobby like 'yes' and student != "no") or  years_coding like '0-2 years';
```

![image](https://user-images.githubusercontent.com/34594339/137607320-1b40131c-acd1-4f12-8727-5279b821ec32.png)

![image](https://user-images.githubusercontent.com/34594339/137607321-2e80111b-d2eb-42d6-88fc-e757bfbdc9b6.png)

![image](https://user-images.githubusercontent.com/34594339/137607330-379073ac-9563-48c6-9517-f89d71f4c4db.png)

👉 duration : `0.077 sec` (m1 mac)  

<br>


#### covid에선 hospital_id보다 앞에 programmer_id를 인덱싱

![image](https://user-images.githubusercontent.com/34594339/137607357-e24d2d28-76cf-4895-8927-e7f0d04ee147.png)

![image](https://user-images.githubusercontent.com/34594339/137607359-6110443d-2485-4a6d-8771-7767a4985ba7.png)

![image](https://user-images.githubusercontent.com/34594339/137607364-1566ecd8-e4ee-4987-ad54-cead15c32303.png)

👉 duration : `0.037 sec` (m1 mac) / `0.000 sec` (0.000 이하로 내려가면 측정 X) (win)


<br>

## 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

```SQL
select stay, count(*) as total
from covid
	inner join (select id as h_id, name from hospital where name = '서울대병원') as h
	on hospital_id = h.h_id
	inner join (select id as m_id, age from member where age between 20 and 29) as m
	on member_id = m.m_id
group by stay;
```

![image](https://user-images.githubusercontent.com/34594339/137607390-dde91f54-0a74-442e-b004-a2be27610340.png)

![image](https://user-images.githubusercontent.com/34594339/137607391-1f5ccc46-ca7f-4b7d-92c9-98cf56e64fd1.png)

![image](https://user-images.githubusercontent.com/34594339/137607392-8492d508-a0cf-4698-af96-b5e494ad73d4.png)

![image](https://user-images.githubusercontent.com/34594339/137607394-f9efa754-d75a-49ee-905c-3e97eb40ab5a.png)

👉 duration : `0.109 sec` (m1 mac) / `0.031 sec` (win)

<br>

#### hospital name을 인덱싱

![image](https://user-images.githubusercontent.com/34594339/137607397-1fef78a3-96cb-4022-8793-4f41cefb3abb.png)

![image](https://user-images.githubusercontent.com/34594339/137607398-20505be5-eb71-4140-925e-ec0794e0d49e.png)

![image](https://user-images.githubusercontent.com/34594339/137607400-647df35d-178b-4126-902f-b095ad5ea259.png)

![image](https://user-images.githubusercontent.com/34594339/137607403-6ed419d3-47e9-4f56-9b05-c578faaf8917.png)

👉 duration : `0.100 sec` (m1 mac) 

<br>

#### member의 age 인덱싱

![image](https://user-images.githubusercontent.com/34594339/137607417-03fc42be-0c19-4855-b95c-64d24c32b323.png)

![image](https://user-images.githubusercontent.com/34594339/137607420-5dc92f0f-ef91-434d-be1c-f2154a1c49b2.png)

![image](https://user-images.githubusercontent.com/34594339/137607424-82b5957e-d5a6-4417-a6a7-877dac0d6db5.png)


👉 duration : `0.0057 sec` (m1 mac) / `0.000 sec` (측정 X) (win)

<br>

## 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

```SQL
select p.exercise, count(*) as total
from covid as c
	inner join (select id as p_id, exercise from programmer) as p
    on c.programmer_id = p.p_id
    inner join (select id from hospital where name = '서울대병원') as h
    on c.hospital_id = h.id
	inner join (select id as m_id, age from member where age between 30 and 39) as m
    on c.member_id = m.m_id
    group by p.exercise;
```

![image](https://user-images.githubusercontent.com/34594339/137607449-c97935c4-9749-4ee1-9995-e29b1c15f240.png)

![image](https://user-images.githubusercontent.com/34594339/137607451-7b233f61-2219-4fa3-98ae-7256ca8a1f54.png)

![image](https://user-images.githubusercontent.com/34594339/137607455-90095c81-bc5e-481a-acfe-d9df4ca30873.png)

![image](https://user-images.githubusercontent.com/34594339/137607456-7fd33514-a66d-4d2d-bfa4-ff9e6f718c72.png)

👉 duration : `0.172 sec` (m1 mac) / `0.047sec` (win)

<br>

#### covid 테이블에 member_id 인덱싱

![image](https://user-images.githubusercontent.com/34594339/137607467-3bdd9c74-01a2-44b4-94e2-07a97c143a06.png)

![image](https://user-images.githubusercontent.com/34594339/137607469-c3a74bd3-1a02-44c8-afb4-30c2ef6f4396.png)

![image](https://user-images.githubusercontent.com/34594339/137607471-8e499a9b-7206-489f-8e54-744214167b17.png)

![image](https://user-images.githubusercontent.com/34594339/137607473-b8c61096-52be-4451-8ca9-de989bf7f9bb.png)

👉 duration : `0.133 sec` (m1 mac) / `0.031 sec` (win)

<br>

### 기존의 hospital 인덱스보다 member 인덱스의 카디널리티가 더 높다. member 인덱스를 우선적으로 인덱싱

![image](https://user-images.githubusercontent.com/34594339/137607494-a5edc7c8-f135-4dc3-8fc7-bc56c3d334c6.png)

👉 duration : `0.111 sec` (mac) / `0.000 sec` (측정 x) (win)














