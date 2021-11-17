# 🚀 조회 성능 개선하기

## A. 쿼리 연습

> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)

```SQL
SELECT 연봉상위5위관리자들.사원번호,
       사원.이름,
       연봉상위5위관리자들.연봉,
       사원출입기록.지역,
       사원출입기록.입출입구분,
       사원출입기록.입출입시간
FROM   사원
       INNER JOIN (SELECT 부서관리자들.사원번호,
                    급여.연봉
             FROM   급여
                    INNER JOIN (
						SELECT 부서관리자.사원번호
						FROM   부서
                                 INNER JOIN 부서관리자
                                   ON 부서.부서번호 = 부서관리자.부서번호
						WHERE  부서.비고 = 'active' AND 부서관리자.종료일자 > Now()
                          ) AS 부서관리자들
                      ON 부서관리자들.사원번호 = 급여.사원번호
             WHERE  급여.종료일자 > Now()
             ORDER  BY 급여.연봉 DESC
             LIMIT  5) AS 연봉상위5위관리자들
         ON 연봉상위5위관리자들.사원번호 = 사원.사원번호
       INNER JOIN 사원출입기록
         ON 연봉상위5위관리자들.사원번호 = 사원출입기록.사원번호
       INNER JOIN 직급
         ON 연봉상위5위관리자들.사원번호 = 직급.사원번호
WHERE  직급.종료일자 > Now() AND 입출입구분 = 'O'
ORDER  BY 연봉상위5위관리자들.연봉 DESC
```

### 실행 결과 

![image](https://user-images.githubusercontent.com/50273712/137785717-8170860d-e21d-449d-a12e-a85df9f0cbf0.png)

![image](https://user-images.githubusercontent.com/50273712/137785820-89ac5c5e-ab52-4811-bc11-d924654e1c21.png)

## B. 인덱스 설계

![image](https://user-images.githubusercontent.com/50273712/137785970-e17458ef-6fb3-458f-affa-1c12df76f52a.png)

부서, 사원출입기록에서 Full Table Scan이 발생함.

사원출입기록의 사원번호에 인덱스 걸어줌. 부서는 큰 효과가 없어서 만들었다가 지웠다.

### 실행 결과

![image](https://user-images.githubusercontent.com/50273712/137785926-9f4ad9dd-3760-411e-81fc-43998691d549.png)

---

---

- [x] [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.

```sql
select hobby, round(count(*) / (select count(*) from programmer) * 100, 1) as percentage 
from programmer 
group by hobby desc;

create index idx_hobby on programmer(hobby);
```

### 실행 결과

![image](https://user-images.githubusercontent.com/50273712/137786400-17fe1fa6-dda9-4f92-bfa0-023a889e15d8.png)

![image](https://user-images.githubusercontent.com/50273712/137786476-e319a9b2-0eda-4f89-9359-66f35e432074.png)
    
    

- [x] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)

```sql
select programmer_id, hospital.name 
from covid inner join programmer on programmer_id = covid.programmer_id
inner join hospital on hospital.id = covid.hospital_id;

create index idx_programmer_id on covid(programmer_id);
create index idx_covid_hospital_id on covid(hospital_id);
```

![image](https://user-images.githubusercontent.com/50273712/137786932-27b798f3-2be8-4508-b67c-4d062b0d22a9.png)

![image](https://user-images.githubusercontent.com/50273712/137787156-879c745b-be86-498a-a3fb-c1fee219abed.png)

- [x] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

```sql
alter table programmer drop index idx_hobby; // 오히려 느리길래 기존 인덱스를 지웠음

select covid.id, hospital.name, programmer.hobby, programmer.dev_type, programmer.years_coding 
from hospital inner join covid on covid.hospital_id = hospital.id
inner join programmer on covid.programmer_id = programmer.id
where (programmer.hobby = 'yes' and programmer.student = 'yes') or programmer.years_coding_prof = '0-2 years'

create index idx_covid_hospital_id on covid(hospital_id);
```

- [x] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

```sql
select covid.stay, count(*) 
from covid inner join (select id from hospital where name = '서울대병원') h on h.id = covid.hospital_id 
inner join (select id from programmer where country = 'India') i on i.id = covid.programmer_id
inner join (select id, age from member where age between 20 and 29) m on m.id = covid.member_id
group by covid.stay
order by null;
```

![image](https://user-images.githubusercontent.com/50273712/137787295-f34e9ec3-689b-45cb-b48a-9171b3a73026.png)

![image](https://user-images.githubusercontent.com/50273712/137787353-33c55545-0406-4e75-8009-4a57dd073991.png)

![image](https://user-images.githubusercontent.com/50273712/137787399-b5f05c75-b7df-4058-b2fc-e9f0b7057575.png)

![image](https://user-images.githubusercontent.com/50273712/137787468-0188e6fc-bb98-4c07-89ef-05410d5774da.png)

- covid.hospital_id에 인덱스 걸어주고 난 실행 시간과 실행 계획
![image](https://user-images.githubusercontent.com/50273712/137787517-8d830ee6-da7b-4e76-9457-4f6e63cf43d5.png)

- covid.programmer_id, covid.member_id에 인덱스 걸어주고 난 실행 시간과 실행 계획
![image](https://user-images.githubusercontent.com/50273712/137787556-1594be20-8178-44a6-b53f-5057c6f638a2.png)

- [x] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

```sql
select programmer.exercise, count(*) from programmer
inner join covid on covid.programmer_id = programmer.id
inner join (select id from hospital where name = '서울대병원') h on h.id = covid.hospital_id
inner join (select id from member where age between 30 and 39) m on covid.member_id = m.id
group by programmer.exercise;
```

![image](https://user-images.githubusercontent.com/50273712/137787584-75bfe48c-0c00-4e22-86c2-dc11afe102fc.png)

![image](https://user-images.githubusercontent.com/50273712/137787649-3bba135e-a8e9-451a-9509-6911384461c1.png)