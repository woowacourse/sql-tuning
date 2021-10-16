# 🚀 조회 성능 개선하기

## A. 쿼리 연습
> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)

### 쿼리 작성만으로 1s 이하로 반환한다.
```
select 상위부서관리자.사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간
from (select 부서관리자.사원번호, 사원.이름, 급여.연봉, 직급.직급명
	  from 부서, 부서관리자, 사원, 급여, 직급
      where 부서관리자.부서번호 = 부서.부서번호 and 부서관리자.사원번호 = 사원.사원번호 and 부서관리자.사원번호 = 직급.사원번호 and 부서관리자.사원번호 = 급여.사원번호
      and 부서관리자.종료일자 > now() and 직급.종료일자 > now() and 급여.종료일자 > now() and 부서.비고 = 'active'
      order by 연봉 desc limit 5) as 상위부서관리자, 사원출입기록
where 상위부서관리자.사원번호 = 사원출입기록.사원번호 and 사원출입기록.입출입구분 = 'O'
order by 연봉 desc, 지역;
```

### 인덱스 설정을 추가하여 50ms 이하로 반환한다.
```
create index idx_사원번호 on 사원출입기록 (사원번호);
```

## B. 인덱스 설계
> 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환

### 1. [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.
```
select hobby, round(count(hobby) / (select count(*) from programmer) * 100, 1) as percent
from programmer group by hobby;

create index idx_hobby on programmer (hobby);
```


### 2. 각 프로그래머별로 해당하는 병원 이름을 반환하세요 (covid.id, hospital.name)
```
select covid.id, hospital.name from covid
join programmer on programmer.id = covid.programmer_id
join hospital on hospital.id = covid.hospital_id;

alter table hospital add primary key (id);
alter table programmer add primary key (id);

create index idx_covid_programmer_id on covid (programmer_id);
```

### 3. 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)
```
select covid.id, hospital.name from covid
join programmer on programmer.id = covid.programmer_id
join hospital on hospital.id = covid.hospital_id
where programmer.hobby = 'yes' and (programmer.dev_type like '%student%' or programmer.years_coding = '0-2 years');
```

### 4. 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)
```
select covid.stay, count(*) as count from covid
join member on member.id = covid.member_id
join hospital on hospital.id = covid.hospital_id
join programmer on programmer.id = covid.programmer_id
where hospital.name = '서울대병원' and  programmer.country = 'india' and member.age between 20 and 29
group by covid.stay;

alter table hospital modify column name varchar(255);
create index idx_name on hospital (name);

create index idx_member_age on member (age);

alter table hospital add unique index name_unique (name);
```

### 5. 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)
```
select programmer.exercise, count(*) as count from covid
join programmer on covid.programmer_id = programmer.id
join member on covid.member_id = member.id
join hospital on covid.hospital_id = hospital.id
where hospital.name = '서울대병원' and member.age between 30 and 39
group by programmer.exercise;
```
