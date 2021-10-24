# 🚀 조회 성능 개선하기

## A. 쿼리 연습

### * 실습환경 세팅

```sh
$ docker run -d -p 23306:3306 brainbackdoor/data-tuning:0.0.1
```
- [workbench](https://www.mysql.com/products/workbench/)를 설치한 후 localhost:23306 (ID : user, PW : password) 로 접속합니다.

<div style="line-height:1em"><br style="clear:both" ></div>

> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)

- 급여 테이블의 사용여부 필드는 사용하지 않습니다. 현재 근무중인지 여부는 종료일자 필드로 판단해주세요.

<div style="line-height:1em"><br style="clear:both" ></div>


<img width="427" alt="aacb272f851f4d66b944bb08f77bdc9b" src="https://user-images.githubusercontent.com/53412998/136698994-96692452-d592-4e61-8f09-2865fa96f2ee.png">

### 쿼리
```sql
select `상위_연봉_부서관리자`.사원번호, `상위_연봉_부서관리자`.이름, `상위_연봉_부서관리자`.연봉, `상위_연봉_부서관리자`.직급명, 사원출입기록.입출입시간, 사원출입기록.지역, 사원출입기록.입출입구분 
from (select 사원.사원번호, 사원.이름, `재직자의_연봉`.연봉, 직급.직급명 
from (select 사원번호, 직급명 from tuning.직급 where date(종료일자) = '9999-01-01') as 직급 
inner join (select 사원번호, 이름 from tuning.사원) as 사원
on 직급.사원번호 = 사원.사원번호 
inner join (select 사원번호, 연봉 from tuning.급여 where date(종료일자) = '9999-01-01') as `재직자의_연봉` 
on 사원.사원번호 = `재직자의_연봉`.사원번호 
inner join (select 사원번호, 부서번호 from tuning.부서관리자 where date(종료일자) = '9999-01-01') as `재직중인_부서관리자` 
on `재직자의_연봉`.사원번호 = `재직중인_부서관리자`.사원번호 
inner join (select 부서번호 from tuning.부서 where 비고 = 'Active') as `활동중인_부서` 
on `재직중인_부서관리자`.부서번호 = `활동중인_부서`.부서번호
order by `재직자의_연봉`.연봉 desc
limit 0,5) as `상위_연봉_부서관리자` 
inner join (select 사원번호, 입출입구분, 입출입시간, 지역 from tuning.사원출입기록 where 입출입구분 = 'O') as 사원출입기록 
on `상위_연봉_부서관리자`.사원번호 = 사원출입기록.사원번호
order by `상위_연봉_부서관리자`.연봉 desc;
```

<div style="line-height:1em"><br style="clear:both" ></div>

- [x] 쿼리 작성만으로 1s 이하로 반환한다.

  <img width="1392" alt="스크린샷 2021-10-15 오후 6 07 28" src="https://user-images.githubusercontent.com/53412998/137462658-469eeef2-90be-4562-91ae-21c35505a32f.png">

<div style="line-height:1em"><br style="clear:both" ></div>

- [x] 인덱스 설정을 추가하여 50 ms 이하로 반환한다.

  `사원출입기록` 테이블의 `사원번호` 컬럼에 `INDEX`를 설정해 조회 시간을 `0.0028sec(2.8ms)`까지 줄여봤습니다.
  
  <img width="1402" alt="스크린샷 2021-10-15 오후 6 10 10" src="https://user-images.githubusercontent.com/53412998/137462994-0c0b6d4d-1ebe-437c-8377-cc00f0b40889.png">

<br/>

## B. 인덱스 설계

### * 실습환경 세팅

```sh
$ docker run -d -p 13306:3306 brainbackdoor/data-subway:0.0.2
```
- [workbench](https://www.mysql.com/products/workbench/)를 설치한 후 localhost:13306 (ID : root, PW : masterpw) 로 접속합니다.

<div style="line-height:1em"><br style="clear:both" ></div>

### * 요구사항

- [x] 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환

    - [x] [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.
    
      - 쿼리
        ```sql
        select hobby, round(count(*) * 100 / (select count(*) from subway.programmer),1) as percentage from subway.programmer
        group by hobby
        order by null;
        ```
        
      - `programmer` 테이블
        - `id` 컬럼에 `PK`, `UNIQUE` 설정
        - `hobby` 컬럼에 `INDEX` 설정
        
      - 실행 결과
        <img width="1360" alt="스크린샷 2021-10-15 오후 5 48 11" src="https://user-images.githubusercontent.com/53412998/137459882-5f5b6556-9215-4a40-9e6f-4cbc7d1be0aa.png">

      
    - [x] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)
      
      - 쿼리
        ```sql
        select covid.programmer_id, hospital.name as hospital_name
        from (select id, programmer_id, hospital_id from subway.covid where programmer_id is not null) as covid 
        inner join (select id, name from subway.hospital) as hospital
        on covid.hospital_id = hospital.id
        limit 0,100;
        ```
        
      - `hospital` 테이블
        - `id` 컬럼에 `PK`, `UNIQUE` 설정
     
      - `covid` 테이블
        - `id` 컬럼에 `PK`, `UNIQUE` 설정
        - `(programmer_id, hospital_id)` `INDEX` 설정

      - 실행 결과
        <img width="1236" alt="스크린샷 2021-10-11 오전 1 33 24" src="https://user-images.githubusercontent.com/53412998/136704973-b658a575-133c-4759-bb84-68f1767919c1.png">

    - [x] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)
      - 쿼리
        ```sql
        select programmer.id as programmer_id, hospital.name as hospital_name
        from (select programmer_id, hospital_id from subway.covid where programmer_id is not null) as covid 
        inner join (select id, hobby, dev_type, years_coding from subway.programmer where (hobby = 'Yes' and dev_type = 'Student') or years_coding = '0-2 years') as programmer 
        on programmer.id = covid.programmer_id 
        inner join (select id, name from subway.hospital) as hospital
        on covid.hospital_id = hospital.id
        limit 0,100;
        ```
    
      - `programmer` 테이블
        - `dev_type` 컬럼 `TEXT` 타입에서 `VARCHAR(500)`으로 변경
        - `hobby` 컬럼 `INDEX` 삭제
        - `(hobby, dev_type)` `INDEX` 설정
        - `years_coding` 컬럼 `INDEX` 설정
      
      - 실행 결과
        <img width="1377" alt="스크린샷 2021-10-11 오전 1 40 23" src="https://user-images.githubusercontent.com/53412998/136705397-62a8a983-d6fc-435f-b1d0-31d5fa66bd2c.png">

    - [x] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)
    
      - 쿼리
        ```sql
        select covid.stay, count(india_programmer.id) as india_programmers 
        from (select id, programmer_id, hospital_id, member_id, stay from subway.covid where programmer_id is not null) as covid
        inner join (select id, member_id from subway.programmer where country = 'India') as india_programmer 
        on covid.programmer_id = india_programmer.id 
        inner join (select id from subway.member where age between 20 and 29) as twenties_member
        on covid.member_id = twenties_member.id
        inner join (select id from subway.hospital where name = '서울대병원') as hospital
        on covid.hospital_id = hospital.id
        group by covid.stay
        order by null;
        ```
        
       - hospital 테이블
         - `name` 컬럼 데이터 타입 `TEXT`에서 `VARCHAR(255)`로 변경
         - `name` 컬럼 `UNIQUE` `INDEX` 설정

       - covid 테이블
         - `(hospital_id, member_id, programmer_id, stay)` `INDEX` 생성
     
       - 실행 결과
        <img width="1360" alt="스크린샷 2021-10-15 오후 5 59 17" src="https://user-images.githubusercontent.com/53412998/137461640-64437153-f0b0-4e67-a7c3-2131837462f0.png">


    - [x] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)
      
      - 쿼리
        ```sql
        select programmer.exercise, count(programmer.id) 
        from (select id, age from subway.member where age between 30 and 39) as thirties_member
        inner join (select programmer_id, member_id, hospital_id from covid) as covid
        on covid.member_id = thirties_member.id
        inner join (select id, exercise from subway.programmer) as programmer
        on covid.programmer_id = programmer.id
        inner join (select id from subway.hospital where name = '서울대병원') as SNU_hospital
        on SNU_hospital.id = covid.hospital_id
        group by programmer.exercise
        order by null;
        ```

      - 실행 결과
        <img width="1361" alt="스크린샷 2021-10-15 오후 6 03 49" src="https://user-images.githubusercontent.com/53412998/137462210-bc9e71e9-b34a-40cb-9b0c-7a10b8224741.png">



<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

## C. 프로젝트 요구사항

### a. 페이징 쿼리를 적용 

### b. Replication 적용 
