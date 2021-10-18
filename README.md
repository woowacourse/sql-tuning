# 🚀 조회 성능 개선하기

## A. 쿼리 연습

### * 실습환경 세팅

```sh
$ docker run -d -p 23306:3306 brainbackdoor/data-tuning:0.0.1
```
- [workbench](https://www.mysql.com/products/workbench/)를 설치한 후 localhost:23306 (ID : user, PW : password) 로 접속합니다.

- [x] **활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들**이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
  (사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)

```sql
select 다섯명.사원번호, 다섯명.이름, 다섯명.연봉, 다섯명.직급명, 사원출입기록.입출입시간, 사원출입기록.지역, 사원출입기록.입출입구분
	from (select 부서관리자.사원번호, 사원.이름, 급여.연봉, 직급.직급명 from 부서
			join 부서관리자 on 부서.부서번호 = 부서관리자.부서번호 
      join 사원 on 사원.사원번호 = 부서관리자.사원번호
			join 급여 on 부서관리자.사원번호 = 급여.사원번호
			join 직급 on 부서관리자.사원번호 = 직급.사원번호
			where 부서.비고 = 'active' and 부서관리자.종료일자 > '2021-10-11' and 급여.종료일자 > '2021-10-11' and 직급.종료일자 > '2021-10-11' 
			order by 급여.연봉 desc limit 5) as 다섯명
	join 사원출입기록 on 사원출입기록.사원번호 = 다섯명.사원번호
    where 사원출입기록.입출입구분 = 'O'
	order by 다섯명.연봉 desc 
```

- 0.394 sec



### 인덱스설정 추가

```
CREATE INDEX `idx_사원_입출입구분_사원`  ON `tuning`.`사원출입기록` (사원번호,입출입구분);
```

0.0019sec



## ERD

![Screen Shot 2021-10-14 at 9 31 03 PM](https://user-images.githubusercontent.com/28701943/137318498-568c230f-b2ae-4061-8311-52b90dcc38e5.png)


<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>


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

      - hobby 에 인덱스 생성(0.087sec)

      ```sql
      SELECT hobby, round((count(hobby) / (select count(*) from programmer)) * 100, 1) from programmer group by hobby order by hobby desc;
      ```

    - [x] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)

      - 조인 연결 key 들은 양쪽 다 인덱스를 가지고 있는 것이 좋아요. 
        - hospital.id, covid.hospital_id 에 index 생성 (0.0056sec -> 0.0036sec)

      ```sql
      select covid.programmer_id, hospital.name from covid
      	join hospital on hospital.id = covid.hospital_id
          where covid.programmer_id is not null;
      ```

    - [x] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

      - Covid_programmer_id 인덱스 생성 (3.751sec -> 0.0073sec)

      ```sql
      select programmer.id, hospital.name, programmer.hobby, programmer.dev_type, programmer.years_coding from programmer 
      	join covid on covid.programmer_id = programmer.id
      	join hospital on hospital.id = covid.hospital_id
      where (hobby = 'yes' and student like('yes%')) or (years_coding='0-2 years' and years_coding is not null)
      order by programmer.id;
      ```

    - [x] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

      - join 하는 테이블 id값들은 이미 인덱스 걸려있었음.
      - where 문에서 hospital name 부분때문에 full scan 하는거 확인
      - text 타입이라서 인덱스가 걸리지 않았음 -> varchar로 변경후 인덱스 적용(0.064sec -> 0.041sec)

      ```sql
      select covid.stay, count(programmer.id) from hospital
      	left join covid on hospital.id = covid.hospital_id
      	left join programmer on covid.programmer_id = programmer.id
      	left join member on member.id = covid.member_id
          where hospital.name = '서울대병원' and programmer.country = 'India' and member.age between 20 and 29
          group by covid.stay;
      ```

    - [x] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

      - member.age 인덱스 적용 (0.068 sec -> 0.045 sec)

      ```sql
      select programmer.exercise, count(programmer.id) from hospital
      	inner join covid on hospital.id = covid.hospital_id
      	inner join programmer on covid.programmer_id = programmer.id
      	inner join member on member.id = covid.member_id
          where hospital.name = '서울대병원' and member.age between 30 and 39
          group by programmer.exercise;
      ```

      

## ERD

![Screen Shot 2021-10-14 at 9 35 54 PM](https://user-images.githubusercontent.com/28701943/137318398-4c9ee455-c61f-491d-9cfa-f28351efdc00.png)

<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

## C. 프로젝트 요구사항

### a. 페이징 쿼리를 적용 

### b. Replication 적용 
