# 🚀 조회 성능 개선하기

## A. 쿼리 연습

### 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)

### 1. 쿼리 작성만으로 1s 이하로 반환한다.
``` sql
select base.사원번호, base.이름, base.연봉, base.직급명, record.입출입시간, record.지역, record.입출입구분
from (select manager.사원번호, employee.이름, salary.연봉, rank.직급명
	from (select 사원번호, 시작일자, 종료일자
		from 부서, 부서관리자
		where 부서.비고 = 'active' and 부서.부서번호 = 부서관리자.부서번호 and 부서관리자.시작일자 <= now() and 부서관리자.종료일자 >= now()) manager
	inner join (select 사원번호, 이름 
		from 사원) employee
	on manager.사원번호 = employee.사원번호
	inner join (select 사원번호, 연봉, 시작일자, 종료일자 
		from 급여) salary
	on manager.사원번호 = salary.사원번호 and salary.시작일자 <= now() and salary.종료일자 >= now()
	inner join (select 사원번호, 직급명, 시작일자, 종료일자 
		from 직급) rank
	on manager.사원번호 = rank.사원번호 and rank.시작일자 <= now() and rank.종료일자 >= now()
	order by salary.연봉 desc limit 5) base
inner join (select 사원번호, 입출입시간, 입출입구분, 출입문, 지역 
	from 사원출입기록) record
on base.사원번호 = record.사원번호 and record.입출입구분 = 'O'
order by base.연봉 desc;
```
![image](https://user-images.githubusercontent.com/66653739/137673293-152442ea-8596-4a90-96c1-322152396ae6.png)
![image](https://user-images.githubusercontent.com/66653739/137673345-3fa42800-b1bb-4726-bf22-82a9135a0f59.png)

### 2. 인덱스 설정을 추가하여 50 ms 이하로 반환한다.
``` sql
ALTER TABLE 사원출입기록 ADD INDEX index_사원출입기록(사원번호, 입출입구분)
```
![image](https://user-images.githubusercontent.com/66653739/137674518-24b34bc6-1ed9-4aba-b59a-c84b09ff60a7.png)


## B. 인덱스 설계

### 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환

### 1. [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.
``` sql
select hobby response, count(*) * 100 / (select count(*) 
	from programmer) percentage
from programmer
group by hobby
order by hobby desc;

ALTER TABLE programmer ADD INDEX index_programmer(hobby);
```
![image](https://user-images.githubusercontent.com/66653739/137677478-bd2adfe7-3165-46a7-97b3-c84dbcaf4ef6.png)
![image](https://user-images.githubusercontent.com/66653739/137677512-9146d3d7-08f1-40d8-9a4d-9d32250a29c2.png)


### 2. 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)
``` sql
select c.id, c.programmer_id, c.hospital_id, h.name
from covid c
inner join (select * 
	from hospital) h
on c.hospital_id = h.id
where c.programmer_id is not null;

ALTER TABLE covid ADD UNIQUE(id);
```
![image](https://user-images.githubusercontent.com/66653739/137678711-f80afd43-6326-4d12-ad9f-6b4130e2b2be.png)
![image](https://user-images.githubusercontent.com/66653739/137678734-ce733443-e1b3-4315-9a48-d5ffdd71f58d.png)


### 3. 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

### 4. 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

### 5. 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)
