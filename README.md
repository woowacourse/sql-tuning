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

  - 1차 1.527sec, 답은 맞지만 5명 제한 없음

    ```sql
    select 사.사원번호, 원.이름, 급.연봉, 직.직급명, 사.지역, 사.입출입구분, 사.입출입시간 
    from 급여 급
    inner join 부서관리자 관 on 관.사원번호 = 급.사원번호
    inner join 부서 부 on 관.부서번호 = 부.부서번호
    inner join 사원출입기록 사 on 사.사원번호 = 관.사원번호
    inner join 사원 원 on 원.사원번호 = 사.사원번호
    inner join 직급 직 on 직.사원번호 = 원.사원번호
    where 사.입출입구분 = 'O' and 직.직급명 = 'Manager' and 부.비고 = 'Active' and 급.종료일자 > 사.입출입시간 and 직.종료일자 > 사.입출입시간
    order by 급.연봉 desc;
    ```

    ![스크린샷 2021-10-16 오후 6 47 03](https://user-images.githubusercontent.com/43775108/137582972-d58cf610-9459-4518-b8ef-8016fa9e942b.png)

  - 2차 0.654sec, where 절을 각 join 문에 서브쿼리로 주어 개선, 5명 제한 없음

    ```sql
    select 사.사원번호, 사원.이름, 급.연봉, 직.직급명, 사.지역, 사.입출입구분, 사.입출입시간 
    from 사원 사원
    inner join 부서관리자 관 on 관.사원번호 = 사원.사원번호
    inner join (select 사원번호, 직급명 from 직급 where 직급명 = 'Manager' and 종료일자 = '9999-01-01') 직 on 직.사원번호 = 관.사원번호
    inner join (select 사원번호, 연봉 from 급여 where 종료일자 = '9999-01-01') 급 on 급.사원번호 = 직.사원번호
    inner join (select 부서번호 from 부서 where 비고 = 'Active') 부 on 관.부서번호 = 부.부서번호
    inner join (select 사원번호, 지역, 입출입구분, 입출입시간 from 사원출입기록 where 입출입구분 = 'O') 사 on 사.사원번호 = 급.사원번호
    order by 급.연봉 desc, 사.입출입시간 desc;
    ```

    ![스크린샷 2021-10-16 오후 6 46 22](https://user-images.githubusercontent.com/43775108/137582958-4a81f764-ab38-4f35-872d-16fcb067cc27.png)

  - 3차 0.427sec, 부서관리자 연봉 top 5명 거르고 그들의 입출입 기록 도출

    ```sql
    select 부서관리자들.사원번호, 부서관리자들.이름, 부서관리자들.연봉, 부서관리자들.직급명, 사.지역, 사.입출입구분, 사.입출입시간 
    from (select 사원.사원번호, 사원.이름, 급.연봉, 직.직급명 from 사원
    inner join 부서관리자 관 on 관.사원번호 = 사원.사원번호
    inner join (select 사원번호, 직급명 from 직급 where 직급명 = 'Manager' and 종료일자 = '9999-01-01') 직 on 직.사원번호 = 관.사원번호
    inner join (select 사원번호, 연봉 from 급여 where 종료일자 = '9999-01-01') 급 on 급.사원번호 = 직.사원번호
    inner join (select 부서번호 from 부서 where 비고 = 'Active') 부 on 관.부서번호 = 부.부서번호
    limit 5) 부서관리자들
    inner join (select 사원번호, 지역, 입출입구분, 입출입시간 from 사원출입기록 where 입출입구분 = 'O') 사 on 사.사원번호 = 부서관리자들.사원번호
    order by 부서관리자들.연봉 desc, 사.입출입시간 desc;
    ```

    ![스크린샷 2021-10-16 오후 8 17 22](https://user-images.githubusercontent.com/43775108/137585312-73a9bc4a-9a18-4da8-906e-d2189dc91883.png)

#### index 추가하기

실행계획 실행 시 아래와 같이 `Full Table Scan` 임을 볼 수 있었다.

![스크린샷 2021-10-16 오후 8 22 06](https://user-images.githubusercontent.com/43775108/137585475-a6e112b9-cc81-40f8-a42c-b18c704211d3.png)

하지만 비용과 시간이 가장 많이 드는 부분은 사원출입기록에 접근하는 부분이었고, 이에 따라 사원번호+입출입시간을 인덱스로 잡아서 처리해보았다.

```sql
create index i_입출입구분_사원번호 on 사원출입기록 (사원번호, 입출입시간);
```

결과는 0.013sec이었다.

![스크린샷 2021-10-16 오후 8 34 02](https://user-images.githubusercontent.com/43775108/137585781-fa685f72-597c-4ef8-8493-63a4f45999af.png)

실행기록에서도 full table scan이 아닌 non-unique key로 바뀌었고 row와 비용도 줄어들었음을 알 수 있었다.

![스크린샷 2021-10-16 오후 8 34 02](https://user-images.githubusercontent.com/437
![스크린샷 2021-10-16 오후 8 35 01](https://user-images.githubusercontent.com/43775108/137585800-3b1c589f-8a25-4156-8c09-86984e7ad66a.png)

하지만 사원번호도 단일, 입출입시간도 단일인데 두개를 같이 거는 것에 의미가 있을까? 라고 생각했고 사원번호만으로 인덱스를 걸어보았다.

```
create index i_사원번호 on 사원출입기록 (사원번호);
```

결과는 0.012sec으로 유사하거나 조금 빨랐다.

![스크린샷 2021-10-16 오후 8 40 59](https://user-images.githubusercontent.com/43775108/137585923-180147bb-332b-41f0-8ddc-6a511b25ac97.png)

그렇다면 더 많은 컬럼을 인덱스로부터 얻어낼 수 있는 복합 인덱스가 유리하다고 판단했고, 첫번째 인덱스로 처리하였다.



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

    - [x] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)

    - [x] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

    - [x] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

    - [x] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

### 인덱스 설계

#### Coding as a Hobby와 같은 결과를 반환하세요.

1. 쿼리

   ```sql
   select hobby, count(*) / (select count(*) from programmer)*100 as percent
   from programmer
   group by hobby desc;
   ```

   결과 441ms

   ![스크린샷 2021-10-16 오후 9 45 54](https://user-images.githubusercontent.com/43775108/137588023-9ee15078-90b9-4c86-b399-ed655cb59bae.png)

2. 인덱스 적용

   ```sql
   create index i_hobby on programmer (hobby);
   ```

   결과 177ms

   ![스크린샷 2021-10-16 오후 9 48 08](https://user-images.githubusercontent.com/43775108/137588118-09808615-4313-4fbd-a7bd-48c3d7be20fb.png)

3. desc 제거하고, round로 반올림 추가하고, id에 pk를 달아주었다.

   ```sql
   select hobby, round(count(*) / (select count(*) from programmer)*100, 1)
   from programmer
   group by hobby;
   ```

   결과 50ms

   ![스크린샷 2021-10-16 오후 11 17 28](https://user-images.githubusercontent.com/43775108/137590960-9e920cfc-a037-4547-9917-d0b6a75749f7.png)

결론적으로 인덱스 적용과 pk가 성능 개선에 가장 큰 효과를 준 것 같다!



#### 프로그래머별로 해당하는 병원 이름을 반환하세요.

1. 쿼리 작성

   ```sql
   SELECT c.programmer_id, h.name FROM subway.covid c
   inner join programmer p on p.id = c.programmer_id
   inner join hospital h on h.id = c.hospital_id
   ```

   결과 0.030

   ![스크린샷 2021-10-17 오전 12 26 17](https://user-images.githubusercontent.com/43775108/137593141-444dd791-4eca-4596-93ac-1451872a7ad2.png)

2. 인덱스 적용

   ```sql
   create index i_covid_programmer_hospital on covid (programmer_id, hospital_id);
   create index i_hospital_id_name on hospital (id, name);
   ```

   결과 0.026

   ![스크린샷 2021-10-17 오전 12 24 44](https://user-images.githubusercontent.com/43775108/137593090-ef71cbcf-b19c-426b-8414-18bc0fa58c21.png)

   ![스크린샷 2021-10-17 오전 12 25 54](https://user-images.githubusercontent.com/43775108/137593123-d31ac55b-d5cb-41e8-86d5-898c7e3a2357.png)

   hospital에도 id, name에 인덱스를 주고 싶었지만 text 형식이라 안되고, 32개의 데이터를 id, name으로 인덱싱하는 것은 불필요하다고 생각했는데 이 생각이 맞는지 모르겠습니다..

#### 프로그래밍이 취미인 학생 혹은 주니어들이 다닌 병원 이름을 반환하고 id 기준 정렬

1. 쿼리 작성

   ```sql
   select p.id, h.name
   from (select id from programmer where (hobby = 'Yes' and student = 'Yes') or years_coding = '0-2 years') p
   inner join covid c on c.programmer_id = p.id
   inner join hospital h on h.id = c.hospital_id;
   ```

   결과 0.082

2. 인덱스 적용

   위에서 i_covid_programmer_hospital을 적용했음에도 인덱스가 적용되지 않았다.

   ![스크린샷 2021-10-17 오전 1 52 05](https://user-images.githubusercontent.com/43775108/137595745-223afb91-0791-4f7a-ba63-e86ea9407893.png)

   따라서 hospital id에 pk를 적용해주었다.

   결과 0.033

   ![스크린샷 2021-10-17 오전 1 49 56](https://user-images.githubusercontent.com/43775108/137595686-ad9750f8-5d2e-4768-94f2-dae44d799082.png)

   다음과 같이 인덱스 적용이 성공적으로 되었고, 시간도 줄었다!

   ![스크린샷 2021-10-17 오전 1 51 17](https://user-images.githubusercontent.com/43775108/137595722-ead694e3-cda3-4b20-a4a2-740b20acbf33.png)

#### 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계

1. 쿼리 작성

   ```sql
   select c.stay, count(c.id) 
   from covid c
   inner join (select id, country from programmer where country = 'India') p on p.id = c.id
   inner join (select id, age from member where age between 20 and 29) m on c.member_id = m.id
   inner join (select id from hospital where name = '서울대병원') h on h.id = c.hospital_id
   group by c.stay;
   ```

   결과 42ms

   ![스크린샷 2021-10-17 오전 2 24 54](https://user-images.githubusercontent.com/43775108/137596632-3c4f7eff-df14-4eff-9938-8d8b6c1eb2ba.png)

   ![스크린샷 2021-10-17 오전 2 26 07](https://user-images.githubusercontent.com/43775108/137596668-8055b99f-39ce-4117-bf8b-fee834f92219.png)

2. 인덱스 추가

   hospital id pk, unique 추가

   Programmer index 추가

   ```
   create index i_p on programmer (country, id);
   ```

   결과 38ms

   ![스크린샷 2021-10-17 오전 2 31 12](https://user-images.githubusercontent.com/43775108/137596805-77703260-0da5-4c04-9d4c-85ca6a7ce449.png)
   ![스크린샷 2021-10-17 오전 2 31 33](https://user-images.githubusercontent.com/43775108/137596826-54018001-559b-4ca6-963e-6afb85d9dd22.png)

   시간은 크게 개선되지 않았지만 programmer의 비용이 개선되었다.

#### 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요.

1. 쿼리작성

   ```sql
   select p.exercise, count(p.id) 
   from programmer p
   inner join covid c on c.programmer_id = p.id
   inner join (select id from hospital where name = '서울대병원') h on h.id = c.hospital_id
   inner join (select id, age from member where age between 30 and 39) m on c.member_id = m.id
   group by p.exercise;
   ```

2. 인덱스 추가

   covid에 아래 인덱스 추가

   ```
   create index i_c on covid (programmer_id, member_id, hospital_id);
   ```

   Hospital name archer(255)로 변경하고 인덱스 추가

   ```
   create index i_h on hospital (name);
   ```

   결과 67ms

   ![스크린샷 2021-10-17 오전 2 58 18](https://user-images.githubusercontent.com/43775108/137597495-e1625577-0ecd-4a07-9b01-8f3910b23d4b.png)

   ![스크린샷 2021-10-17 오전 3 00 17](https://user-images.githubusercontent.com/43775108/137597561-f0f36ffa-b4e1-4384-aa9f-540161f94b4b.png)

   잘 동작하고 있음을 알 수 있다!
