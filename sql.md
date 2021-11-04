[자세한 풀이](https://cobalt-cuticle-030.notion.site/2ab7b78a913042c2807243440a2ea416)

### 첫 번째 문제
```
select 사원정보.사원번호, 이름, 연봉, 직급명, 입출입시간, 지역, 입출입구분 from  
	(select 사원.사원번호, 이름, 연봉, 직급명 from (select 부서번호 from 부서 where 비고 = 'active') A  
	inner join (select 부서번호, 사원번호 from 부서관리자 where 종료일자 >= now()) B on A.부서번호 = B.부서번호  
	inner join (select 직급명, 사원번호 from 직급 where 직급.종료일자 >= now()) C on C.사원번호 = B.사원번호 
	inner join 사원 on C.사원번호 = 사원.사원번호  
	inner join 급여 on 급여.사원번호 = C.사원번호 and 급여.종료일자 >= now()  order by 급여.연봉 desc limit 5) 사원정보  
inner join 사원출입기록 on 사원정보.사원번호 = 사원출입기록.사원번호  
where 입출입구분 = 'O' order by 연봉 desc;
```

### 두 번째 문제
```
select hobby, round(count(hobby) / (select count(1) from programmer) * 100, 1) as ratio from programmer group by hobby order by ratio desc;
```

### 세 번째 문제
```
select programmer.id as '프로그래머 아이디', hospital.name as '병원 이름' from covid 
inner join hospital on covid.hospital_id = hospital.id
inner join programmer on covid.programmer_id = programmer.id;
```

### 네 번째 문제
```
select A.id, name from hospital 
inner join covid on covid.hospital_id = hospital.id
inner join (select id from programmer where (years_coding = '0-2 years' and hobby = 'yes') and (student like 'yes%' and hobby = 'yes')) as A on covid.programmer_id = A.id;
```

### 다섯 번째 문제
```
select covid.stay as 기간, count(1) from covid 
inner join (select id from hospital where name = '서울아산병원') as B on covid.hospital_id = B.id
inner join (select * from programmer inner join (select id as mem_id from member where age >= 20 and age < 30) MEM on MEM.mem_id = programmer.member_id where country = 'India') as A on covid.programmer_id = A.id
group by covid.stay;
```

### 여섯 번째 문제
```
select stay as 기간, count(1) from covid 
inner join (select id from hospital where name = '서울대병원') as B on covid.hospital_id = B.id
inner join (select * from programmer inner join (select id as mem_id from member where age >= 20 and age < 30) MEM on MEM.mem_id = programmer.member_id where country = 'India') as A on covid.programmer_id = A.id
group by stay;
```
