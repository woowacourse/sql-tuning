# 1
```
explain select 사원정보.사원번호, 사원정보.이름, 사원정보.연봉, 사원정보.직급명 from 
(select 사원.사원번호, 이름, 연봉, 직급명 from 사원
	join 부서관리자 on 부서관리자.사원번호 = 사원.사원번호 
	join 부서 on 부서.부서번호 = 부서관리자.부서번호
	join 급여 on 급여.사원번호 = 사원.사원번호 
	join 직급 on 직급.사원번호 = 사원.사원번호 
where 비고 = 'active'
and 부서관리자.종료일자 >= now()
and 직급.종료일자 >= now() 
and 급여.종료일자 >= now() 
order by 급여.연봉 desc limit 5) 사원정보
	join 사원출입기록 on 사원정보.사원번호 = 사원출입기록.사원번호
where 입출입구분 = "O"
order by 연봉 desc
```
# 2
```
select hobby, concat(round(count(hobby) / (
	select count(*) 
    from programmer)* 100, 1), "%") as "Percentage"  
from programmer group by hobby order by hobby DESC
```
# 3
```
select programmer.id, hospital.name from programmer
	JOIN covid on covid.programmer_id = programmer.id
    JOIN hospital on covid.hospital_id = hospital.id
```
# 4
```
select programmer.id, hospital.name from hospital 
	JOIN covid on covid.hospital_id = hospital.id
	JOIN programmer on programmer.id = covid.programmer_id
where (student like 'yes%' and hobby = 'yes') and (years_coding = '0-2 years' and hobby = 'yes')
```
# 5
```
select stay as 기간, count(*) from covid 
	JOIN hospital on covid.hospital_id = hospital.id
    JOIN programmer on covid.programmer_id = programmer.id
    JOIN member on programmer.member_id = member.id
where hospital.name = '서울아산병원'
	and member.age >= 20
    and member.age < 30
    and programmer.country = 'India'
group by stay;
```
# 6
```
select exercise, count(exercise) from programmer 
	JOIN (select id from member where age >= 30 and age < 40) MEM on MEM.id = programmer.member_id
	JOIN (select programmer_id from covid
			JOIN (select id from hospital where hospital.name = '서울대병원') HOS on covid.hospital_id = HOS.id) COV
on COV.programmer_id = programmer.id
group by exercise;
```

이외의 작업 이력은 [여기](https://myagya.notion.site/449e95c367f74e2399daac08c57a27a4)서 확인하실 수 있습니다.
