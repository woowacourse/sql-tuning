## 1. 쿼리 연습

> SQL

```sql
create index `idx_employee_id` on `tuning`.`사원출입기록` (사원번호);

select 부서관리자_급여.사원번호, 부서관리자_급여.이름, 부서관리자_급여.연봉, 부서관리자_급여.직급명, 사원출입기록.입출입시간, 사원출입기록.지역, 사원출입기록.입출입구분
    from (select 부서관리자.사원번호, 사원.이름, 급여.연봉, 직급.직급명
            from 부서관리자
                left join 부서 on 부서관리자.부서번호 = 부서.부서번호
                left join 사원 on 부서관리자.사원번호 = 사원.사원번호
                left join 급여 on 부서관리자.사원번호 = 급여.사원번호
                left join 직급 on 부서관리자.사원번호 = 직급.사원번호
            where 부서.비고 = 'active' and 부서관리자.종료일자 = '9999-01-01' and 급여.종료일자 = '9999-01-01' and 직급.종료일자  = '9999-01-01'
            order by 급여.연봉 desc limit 5
    ) as 부서관리자_급여 left join 사원출입기록 on 부서관리자_급여.사원번호 = 사원출입기록.사원번호
    where 사원출입기록.입출입구분 = 'O' order by 부서관리자_급여.연봉 desc;
```

* 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
  * (사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)

![image](https://user-images.githubusercontent.com/56240505/136753496-fd31ac6d-5353-44ed-b69f-d484bfe47432.png)
![image](https://user-images.githubusercontent.com/56240505/136753542-21876913-2e2a-40b0-9fcd-e23aa13dc159.png)

* 인덱스 적용 전, 쿼리 실행 결과 평균 1초 미만입니다.

> SQL

```sql
create index `idx_employee_id` on `tuning`.`사원출입기록` (사원번호);
```

![image](https://user-images.githubusercontent.com/56240505/136753876-99cddb30-3a44-45e6-82fa-57e56e4d6c0c.png)

* 인덱스 적용 후, 50ms 보다 낮은 15~16ms를 기록했습니다.

<br>

## 2. 인덱스 설계

### 2.1. Coding as a Hobby

> SQL

```sql
alter table programmer add constraint primary key (id);
create index `idx_hobby` on `subway`.`programmer` (hobby);

select hobby, round(count(*) * 100 / (select count(*) from programmer), 1) as ratio
    from programmer
    group by hobby
    order by ratio desc;
```

* programmer 테이블
  * id : PK
  * hobby : index

![image](https://user-images.githubusercontent.com/56240505/136754294-6475db6d-0be4-45a4-82de-4f46b24da24d.png)

![image](https://user-images.githubusercontent.com/56240505/136754364-1fb779de-9649-4210-85bd-1341238aa65b.png)

* 아슬아슬하게 100ms 아래를 기록합니다.

### 2.2. 프로그래머별로 해당하는 병원 이름

> SQL

```sql
alter table hospital add constraint primary key (id);
alter table covid add constraint primary key (id);
create index `idx_programmer_id` on `subway`.`covid` (programmer_id);
create index `idx_hospital_id` on `subway`.`covid` (hospital_id);

select programmer.id as programmer_id, covid.id as covid_id, hospital.name
    from hospital
        left join covid on hospital.id = covid.hospital_id
        left join programmer on covid.programmer_id = programmer.id;
```

* hospital 테이블
  * id : PK
* covid 테이블
  * id : PK
  * programmer_id : index
  * hospital_id : index

![image](https://user-images.githubusercontent.com/56240505/136754664-59044de7-84a3-4904-83ec-8e4cfc41208c.png)
![image](https://user-images.githubusercontent.com/56240505/136754680-28af0cac-d055-4293-b410-1f43866562bd.png)

### 2.3. 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름 반환 및 id 정렬

> SQL

```sql
select covid.id, hospital.name, programmer.hobby, programmer.dev_type, programmer.years_coding
    from hospital
        left join covid on hospital.id = covid.hospital_id
        left join programmer on programmer.id = covid.programmer_id
    where (programmer.hobby = 'Yes' and programmer.dev_type = 'Student') or programmer.years_coding_prof like '0-2%'
    order by programmer.id;
```

* ID 등 필요한 인덱스는 2.2 절의 문제를 풀 때 이미 적용해서, 2.3. 절의 문제를 해결할 때는 별도의 인덱스를 적용하지 않았습니다.
  * 오히려 이전에 설정한 hobby 관련 인덱스를 삭제했습니다.
  * OR 조건이 존재하면 쿼리가 인덱스를 타지 않는다고 해서, 실제로 테스트해보니 hobby, dev_type, years_coding_prof에 대해 인덱스를 걸어도 성능이 동일하네요. :(

![image](https://user-images.githubusercontent.com/56240505/136755101-ded589c1-a7be-461e-a05a-96bae034d9d0.png)
![image](https://user-images.githubusercontent.com/56240505/136755146-5e802692-ec66-45bc-ba9e-c5f0c47e9532.png)

### 2.4. 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계

> SQL

```sql
alter table hospital modify name varchar(255);
create index `idx_hospital_name` on `subway`.`hospital` (name);
create index `idx_member_id` on `subway`.`covid` (member_id);
create index `idx_stay` on `subway`.`covid` (stay);
create index `idx_country` on `subway`.`programmer` (country);
create index `idx_age` on `subway`.`member` (age);

select covid.stay, avg(member.age) as average_age, count(*) as total_count
    from hospital
        inner join covid on hospital.id = covid.hospital_id
        inner join programmer on covid.programmer_id = programmer.id
        inner join member on member.id = covid.member_id
    where hospital.name = '서울대병원' and programmer.country = 'India' and member.age between 20 and 29
    group by covid.stay;
```

* hospital 테이블
  * name 컬럼 속성을 인덱스 적용을 위해 varchar로 수정.
  * name : index
* covid 테이블
  * member_id : index
  * stay : index
* programmer 테이블
  * country : index
* member 테이블
  * age : index

![image](https://user-images.githubusercontent.com/56240505/136756036-14d786fb-edca-4602-82cf-6bd359d9fc3b.png)
![image](https://user-images.githubusercontent.com/56240505/136756083-1788d300-baf2-42dc-a3bd-31bea3cce860.png)

* 개인적으로 hospital 컬럼 속성을 변경하지 않고 문제를 해결해보고 싶었는데, 성능 요구사항을 충족하기 어려워서 변경했습니다.

### 2.5. 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계

> SQL

```sql
select programmer.exercise, avg(member.age) as average_age, count(*) as total_count
    from hospital
        inner join covid on hospital.id = covid.hospital_id
        left join programmer on covid.programmer_id = programmer.id
        left join member on member.id = covid.member_id
    where hospital.name = '서울대병원' and member.age between 30 and 39
    group by programmer.exercise;
```

![image](https://user-images.githubusercontent.com/56240505/136756564-1470b35d-7997-4b19-8977-a1ef4382a4ae.png)
![image](https://user-images.githubusercontent.com/56240505/136756640-0595b48d-2242-4032-afec-d9ef4c299445.png)
