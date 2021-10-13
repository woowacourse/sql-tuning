# 🚀 조회 성능 개선하기

## A. 쿼리 연습

> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)

### 1부 (M1으로 진행)
  ```sql
  select 관리자.사원번호, 이름, 연봉, 직급명, 입출입시간, 지역, 입출입구분 
  from (
      select 관리.사원번호, 관리.부서번호, 사원.이름, 급여.연봉, 직급.직급명
      from 
          부서관리자 관리 
              inner join 
          사원
                  on 관리.사원번호 = 사원.사원번호
              inner join
          부서 
                  on 부서.부서번호 = 관리.부서번호
              inner join
          급여
                  on 급여.사원번호 = 관리.사원번호
              inner join
          직급
                  on 관리.사원번호 = 직급.사원번호
      where 
          급여.종료일자 = '9999.01.01'
              AND
          관리.종료일자 = '9999.01.01'
              AND
          직급.종료일자 = '9999.01.01'
              AND
          부서.비고 = 'ACTIVE'
      order by 급여.연봉 desc
      limit 0, 5
  )관리자 
      inner join
  (
      select 사원번호, max(입출입시간) 입출입시간, 지역, 입출입구분
          from 사원출입기록
      group by 사원번호, 지역, 입출입구분
          having 입출입구분 = 'O'
  ) 기록 
      on
      관리자.사원번호 = 기록.사원번호
  order by 관리자.연봉 desc
  ; 
  ```

  - 실행결과 1
    ```sql
    08:45:12	select ... 14 row(s) returned	22.350 sec / 0.000030 sec
    ```
    > 원하는 결과는 나왔으나, 조회속도가 지나치게 느림

  - 원인 분석 : 부서관리자, 사원, 부서, 급여, 직급은 PK 인덱스가 잡혀있어, 조건 검색 시 인덱스 레인지 스캔이거나 row가 적은 테이블에서의 풀테이블 스캔.
             문제는 다른 테이블과 사원ID의 연관관계뿐인 사원출입기록 테이블이라고 생각함. 데이터도 66만건으로 가장 많고, pk는 순번+사원ID라 사원ID에 대한 인덱싱 효과를 받을 수 없음.
             먼저 사원출입기록의 group by를 최적화하여 중복값 제거를 빠르게 하기 위해, 복합 인덱스를 추가함. 
  
  - 적용
    ```sql
    10:36:55	CREATE INDEX `idx_사원출입기록_사원번호_입출입구분_지역`  ON `tuning`.`사원출입기록` (사원번호, 입출입구분, 지역) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT	OK	0.000 sec
    ```
    
    적용 결과 사원출입기록 inner table만 조회시, 풀테이블 스캔에서 풀인덱스 스캔으로 개선됨.
    
---
    
  - 실행결과 2
    ```sql
    10:38:40	select ...	14 row(s) returned	11.743 sec / 0.000011 sec
     ```
    > 여전히 지나치게 느림
  
  - 원인 분석 :  group by를 진행하고 중복을 제거한 데이터가 너무 많아, 조회 처리가 지연됨. 쿼리를 최적화 해보기로 함.

  - 적용
    - 드라이빙 테이블과 드라이븐 테이블을 가장 큰 모수테이블인 바꿔보기 위해 조인 쿼리의 앞뒤를 뒤바꿔 보았으나, 변화가 없음. 이는 내부적으로 드라이빙/드라이븐 테이블의 결정조건이 있기 때문임.
      https://devuna.tistory.com/36
    - `straight_join` 키워드를 활용하는 방법이 있으나, 현재 원인은 조인순서에 있는 것은 아니라서 기각.
    - 또한 visual excution plan의 쿼리코스트에 대해서도 학습함. 
      https://www.infoworld.com/article/3234637/7-keys-to-better-mysql-performance.html
      > 쿼리 코스트는 쿼리 실행 비용이며, 다양한 요소를 고려하여 결정된다. 일반적으로 1000이하면 가벼운 쿼리, 1,000~100,000은 중간비용쿼리, 그 이상은 비용이 높은 쿼리로 간주된다. 대화형 시스템(우리가 만드는 것 )에서 비용이 높은 쿼리는 경계 대상이다.
    - 모수 테이블을 줄이기 위해, 먼저 조건에 맞는 사원 ID만 조회하여 줄일 수 있도록 사원번호를 서브쿼리로 넘김.
      ```sql
      select 관리자.사원번호, 이름, 연봉, 직급명, 입출입시간, 지역, 입출입구분 
      from
      (
        select 사원번호, max(입출입시간) 입출입시간, 지역, 입출입구분
        from 사원출입기록
        where 사원번호 in(
            select 관리.사원번호
            from
                부서관리자 관리
                    inner join
                부서
                        on 부서.부서번호 = 관리.부서번호
                    inner join
                급여
                        on 급여.사원번호 = 관리.사원번호
            where
                급여.종료일자 = '9999.01.01'
                    AND
                관리.종료일자 = '9999.01.01'
                    AND
                직급.종료일자 = '9999.01.01'
                    AND
                부서.비고 = 'ACTIVE'
              )
        group by 사원번호, 입출입구분, 지역
        having 입출입구분 = 'O'
      ) 기록
      inner join
      (
        select 관리.사원번호, 관리.부서번호, 사원.이름, 급여.연봉, 직급.직급명
          from
            부서관리자 관리
              inner join
            사원
                  on 관리.사원번호 = 사원.사원번호
              inner join
            부서
                  on 부서.부서번호 = 관리.부서번호
              inner join
            급여
                  on 급여.사원번호 = 관리.사원번호
              inner join
            직급
                  on 관리.사원번호 = 직급.사원번호
            where
              급여.종료일자 = '9999.01.01'
              AND
              관리.종료일자 = '9999.01.01'
              AND
              직급.종료일자 = '9999.01.01'
              AND
              부서.비고 = 'ACTIVE'
            order by 급여.연봉 desc
            limit 0, 5
      )관리자
      on 관리자.사원번호 = 기록.사원번호
      order by 관리자.연봉 desc
      ;
      ```
      
---

  - 실행결과 3
      ```sql
      11:20:29	...	14 row(s) returned	0.015 sec / 0.000011 sec
      ```
  - 50ms 미만으로 끝났다고 여겼는데, 새로운 요구사항이 나오면서 지옥열차가 펼쳐졌다.
    > 1. 쿼리 작성만으로 1s 이하로 반환한다.
    > 
    ... 2부에서 계속

### 2부 (M1으로 진행)

  - 인덱스를 초기화 하고나니 4.9초가 나왔다

  - 실행결과 1
    ```sql
    11:27:21	select ... 14 row(s) returned	4.902 sec / 0.000011 sec
    ```
    
  - 원인분석
    - 쿼리최적화가 덜 진행된 탓이라 생각했다.
    - Apple M1칩 + Docker + MySQL 이슈가 있었으나 [링크](https://dev.to/perry/fix-slow-docker-databases-for-apple-silicon-m1-chips-2ip1) 이 땐 몰랐다.

  - 적용
    1. group by, having을 제거했다.
    2. 각 테이블 조회시 최대한 모수를 줄여 조회헀다.
    3. IN절에서의 서브쿼리(where)보다 인라인뷰(from)의 서브쿼리가 더 성능이 좋다. [링크](https://stackoverflow.com/questions/2577174/join-vs-sub-query)
       - [공식문서](https://dev.mysql.com/doc/refman/5.7/en/rewriting-subqueries.html) 를 참고하여, IN절을 인라인뷰로 변경하였다.
    4. 기타 다양한 시도를 반복하며 얻은 쿼리는 다음과 같다.
    ```sql
    select distinct 입출입구분, 입출입시간, 기록.사원번호, 지역, 이름, 직급명, 연봉
    from 
      (select * from 사원출입기록 where 입출입구분 = 'O') 기록
          inner join
            (select 관리.사원번호, 이름, 직급명, 연봉
              from
                  (select 사원번호, 부서번호 from 부서관리자 where 종료일자 = '9999.01.01') 관리
                    inner join
                  (select 이름, 사원번호 from 사원) 사원 on 사원.사원번호 = 관리.사원번호
                    inner join
                  (select 부서번호 from 부서 where 비고 = 'active') 부서 on 부서.부서번호 = 관리.부서번호
                    inner join
                  (select 사원번호, 연봉 from 급여 where 종료일자 = '9999.01.01') 급여 on 급여.사원번호 = 관리.사원번호
                    inner join
                  (select 직급명, 사원번호 from 직급 where 종료일자 = '9999.01.01') 직급 on 직급.사원번호 = 관리.사원번호
            order by 급여.연봉 desc
            limit 0, 5
      ) 고연봉사원 on 고연봉사원.사원번호 = 기록.사원번호
    ;
    ```
---
  - 실행결과 2
    ```sql
    14 row(s) returned, 1.7s
    ```
  - 원인분석
    - 이 때 2019PRO macbook 기종에선 0.5s가 나오는 쿼리지만 몰랐기 때문에... 추가적으로 성능을 개선할 수 있는 방안을 모색했다. 가장 주목했던 건 사원출입기록의 FULL INDEX SCAN이었다.
      (순번, 사원번호)를 PK로, (입출입시간), (지역), (출입문)을 인덱스로 가지고있는 사원출입기록을 INDEX SCAN 할 수 있는 방향이다.
      
  - 적용
    - 논리적으로 입출입시간을 유추하기 위해 가장 머리를 많이 썼다. 직급 테이블에서, 가장 빠른 입사일자 이후로 사원출입기록 테이블에 where문을 거는 식이다. 이외에도 다양하게 서브쿼리로 입출입시간 인덱스에 대한 조회 시도를 했다.
    - 순번을 0 이상으로 줘서 PRIMARY를 유도하고, USE INDEX를 주어 힌트를 주었지만 대개 쿼리 처리속도는 늦어졌다. 
    - 고연봉사원 조회쿼리를 개선하기 위해 다양하게 수정했다.
    - 이 모든 적용은 쿼리를 오히려 늦어지게 만들었다. 효과를 본 건 아래 한 줄이다.
    - 사원번호를 IN절로 주어 사원출입기록 조회를 최소화 시키고, Group By로 PRIMARY 스캔을 유도했다.
    ```sql
    select 입출입구분, 입출입시간, 기록.사원번호, 지역, 이름, 직급명, 연봉
    from (select 사원번호, 입출입시간, 입출입구분, 지역
          from 사원출입기록 use index(primary)
          where 입출입구분 = 'O'
            and 사원번호 IN (select * from (select 관리.사원번호
            from
              (select 사원번호, 부서번호 from 부서관리자 where 종료일자 = '9999.01.01') 관리 
                inner join
              (select 부서번호 from 부서 where 비고 = 'active') 부서 on 부서.부서번호 = 관리.부서번호
                inner join
              (select 사원번호, 연봉 from 급여 where 종료일자 = '9999.01.01') 급여 on 급여.사원번호 = 관리.사원번호
            order by 급여.연봉 desc
            limit 0, 5) 고연봉 )
          group by 순번, 사원번호
         ) 기록
           inner join
         ( select 관리.사원번호, 이름, 직급명, 연봉
           from
               (select 이름, 사원번호 from 사원) 사원
                 inner join
               (select 사원번호, 부서번호 from 부서관리자 where 종료일자 = '9999.01.01') 관리 on 사원.사원번호 = 관리.사원번호
                 inner join
               (select 부서번호 from 부서 where 비고 = 'active') 부서 on 부서.부서번호 = 관리.부서번호
                 inner join
               (select 사원번호, 연봉 from 급여 where 종료일자 = '9999.01.01') 급여 on 급여.사원번호 = 관리.사원번호
                 inner join
               (select 직급명, 사원번호 from 직급 where 종료일자 = '9999.01.01') 직급 on 직급.사원번호 = 관리.사원번호
           order by 급여.연봉 desc
             limit 0, 5
         ) 고연봉사원 on 고연봉사원.사원번호 = 기록.사원번호
    ;
    ```
    
---
  - 실행결과 3
    ```sql
    14 row(s) returned, 1.5s
    ```
  - 원인분석
    - 미궁에 빠져들었다. 이후 무슨 짓을 해도 줄어들지 않았다. 실제로는 IN절에 대해 풀테이블 스캔을 타고 있었는데, 강한 힌트로 인덱스 스캔을 강제로 진행해도 시간이 증가했다. 당시의 explain결과이다. 9번행에 주목하자
    ```sql
    # id, select_type, table, partitions, type, possible_keys, key, key_len, ref, rows, filtered, Extra
    1  '1', 'PRIMARY', '<derived10>', NULL, 'ALL', NULL, NULL, NULL, NULL, '2', '100.00', NULL
    2  '1', 'PRIMARY', '<derived2>', NULL, 'ref', '<auto_key0>', '<auto_key0>', '4', '비쌈.사원번호', '65', '100.00', NULL
    3  '10', 'DERIVED', '부서', NULL, 'ALL', 'PRIMARY', NULL, NULL, NULL, '9', '11.11', 'Using where; Using temporary; Using filesort'
    4  '10', 'DERIVED', '부서관리자', NULL, 'ref', 'PRIMARY,I_부서번호', 'I_부서번호', '12', 'tuning.부서.부서번호', '2', '10.00', 'Using where'
    5  '10', 'DERIVED', '직급', NULL, 'ref', 'PRIMARY', 'PRIMARY', '4', 'tuning.부서관리자.사원번호', '1', '10.00', 'Using where'
    6  '10', 'DERIVED', '급여', NULL, 'ref', 'PRIMARY', 'PRIMARY', '4', 'tuning.부서관리자.사원번호', '9', '10.00', 'Using where'
    7  '10', 'DERIVED', '사원', NULL, 'eq_ref', 'PRIMARY', 'PRIMARY', '4', 'tuning.부서관리자.사원번호', '1', '100.00', NULL
    8  '2', 'DERIVED', '<subquery3>', NULL, 'ALL', NULL, NULL, NULL, NULL, NULL, '100.00', 'Using temporary; Using filesort'
    9  '2', 'DERIVED', '사원출입기록', NULL, 'ALL', 'PRIMARY,I_지역,I_시간,I_출입문', NULL, NULL, NULL, '658935', '1.00', 'Using where; Using join buffer (Block Nested Loop)'
    10  '3', 'MATERIALIZED', '<derived4>', NULL, 'ALL', NULL, NULL, NULL, NULL, '2', '100.00', NULL
    11 '4', 'DERIVED', '부서', NULL, 'ALL', 'PRIMARY', NULL, NULL, NULL, '9', '11.11', 'Using where; Using temporary; Using filesort'
    12  '4', 'DERIVED', '부서관리자', NULL, 'ref', 'PRIMARY,I_부서번호', 'I_부서번호', '12', 'tuning.부서.부서번호', '2', '10.00', 'Using where'
    13  '4', 'DERIVED', '직급', NULL, 'ref', 'PRIMARY', 'PRIMARY', '4', 'tuning.부서관리자.사원번호', '1', '10.00', 'Using where'
    14  '4', 'DERIVED', '급여', NULL, 'ref', 'PRIMARY', 'PRIMARY', '4', 'tuning.부서관리자.사원번호', '9', '10.00', 'Using where'
    15  '4', 'DERIVED', '사원', NULL, 'eq_ref', 'PRIMARY', 'PRIMARY', '4', 'tuning.부서관리자.사원번호', '1', '100.00', 'Using index'
    ```
    힌트를 주어도 옵티마이저는 9번행에 대해 풀테이블스캔을 채택했다.(그게 더 빠르기 때문이겠지) 
    - 이 때 다른 크루의 제출 쿼리를 보고, 의문을 품었다. 0.5s가 나왔다고? 해당 크루의 쿼리를 워크벤치에 가져와 돌려보니 2.4s가 찍혔다.
    - 결과적으로 기종차이였다. M1 실리콘 칩 호환성 문제였고, window pc를 통해 미션을 다시 진행했다.

### 3부 (window에서 진행)

  - 실행결과 1
    ```sql
    14 row(s) returned, 0.297s
    ```
    > 1s 미만으로 나왔으니 성공!
    
  - 원인분석
    - 이제 인덱스를 적용하여 50ms를 수행하면 된다. 2부에서 쿼리 최적화를 진행하며, 사원번호에 대한 인덱스를 갈망했기에 바로 만들어 주었다.
      ```sql
      CREATE INDEX `idx_사원출입기록_사원번호`  ON `tuning`.`사원출입기록` (사원번호) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT
      ```

---

  - 실행결과 2
    ```sql
    14 row(s) returned, 0.000s
    ```
    > 어쩐일인지 0초가 찍혔다. 0ms < 50ms 이므로 성공!

  - 원인분석
    - explain을 다시 찍어보았다. 11행 주목
    ```sql
    # id, select_type, table, partitions, type, possible_keys, key, key_len, ref, rows, filtered, Extra
    1 '1', 'PRIMARY', '<derived2>', NULL, 'ALL', NULL, NULL, NULL, NULL, '2', '100.00', NULL
    2 '1', 'PRIMARY', '<derived10>', NULL, 'ref', '<auto_key0>', '<auto_key0>', '4', '기록.사원번호', '2', '100.00', NULL
    3 '10', 'DERIVED', '부서', NULL, 'ALL', 'PRIMARY', NULL, NULL, NULL, '9', '11.11', 'Using where; Using temporary; Using filesort'
    4 '10', 'DERIVED', '부서관리자', NULL, 'ref', 'PRIMARY,I_부서번호', 'I_부서번호', '12', 'tuning.부서.부서번호', '2', '10.00', 'Using where'
    5 '10', 'DERIVED', '직급', NULL, 'ref', 'PRIMARY', 'PRIMARY', '4', 'tuning.부서관리자.사원번호', '1', '10.00', 'Using where'
    6 '10', 'DERIVED', '급여', NULL, 'ref', 'PRIMARY', 'PRIMARY', '4', 'tuning.부서관리자.사원번호', '9', '10.00', 'Using where'
    7 '10', 'DERIVED', '사원', NULL, 'eq_ref', 'PRIMARY', 'PRIMARY', '4', 'tuning.부서관리자.사원번호', '1', '100.00', NULL
    8 '2', 'DERIVED', '<derived4>', NULL, 'ALL', NULL, NULL, NULL, NULL, '2', '100.00', 'Using temporary; Using filesort; Start temporary'
    9 '2', 'DERIVED', '사원출입기록', NULL, 'ref', 'PRIMARY,I_지역,I_시간,I_출입문,idx_사원출입기록_사원번호', 'idx_사원출입기록_사원번호', '4', 'inn.사원번호', '4', '10.00', 'Using where; End temporary'
    10 '4', 'DERIVED', '부서', NULL, 'ALL', 'PRIMARY', NULL, NULL, NULL, '9', '11.11', 'Using where; Using temporary; Using filesort'
    11 '4', 'DERIVED', '부서관리자', NULL, 'ref', 'PRIMARY,I_부서번호', 'I_부서번호', '12', 'tuning.부서.부서번호', '2', '10.00', 'Using where'
    ```
    - 11행 사원출입기록 행이 사원번호 인덱스를 활용하는 것을 볼 수 있다.
  
## B. 인덱스 설계

### * 요구사항
- [x] 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환
    - [x] [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.
    - [x] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)
    - [x] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)
    - [x] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)
    - [x] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

### 1부 (Window로 진행)

- 개요
  - A단계에서 산전수전 다 겪었기에 B단계는 술술 진행했다. 쿼리와 인덱스 생성, 결과만 소개한다.

### [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.
- 조회쿼리
  ```sql
  select p.hobby, concat(round(count(p.hobby) / (select count(*) from programmer) * 100, 1), '%') percent 
  from programmer p 
  group by p.hobby
  ```
- 실행결과 1
  ```sql
  11:24:50	select ... 2 row(s) returned	3.826 sec / 0.000038 sec
  ```

- 원인분석
  - programmer 테이블에 대한 풀테이블 스캔이다. hobby 칼럼에 대한 인덱싱을 잡아주자. 

- 적용
  - 모든 튜닝에 앞서 테이블의 기본키를 설정해주었다. 
    ```sql
    alter table covid add primary key(id);
    alter table programmer add primary key(id);
    alter table hospital add primary key(id);
    ```
  - 이후 hobby 칼럼에 대해 인덱스를 추가했다.
    ```sql
    CREATE INDEX `idx_programmer_hobby`  ON `subway`.`programmer` (hobby) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT
    ```

- 실행결과 2
  ```sql
  21:36:28	select ......, 2 row(s) returned	0.047 sec / 0.000 sec  
  ```
  > 47ms < 100ms 이므로 성공!
  
### 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)

- 조회쿼리
  ```sql
  select h.name hospital_name, c.id covid_id
  from programmer p
          inner join 
      covid c
          on c.member_id = p.id and c.member_id is not null
          inner join
      hospital h
          on h.id = c.hospital_id;
  ```

- 실행결과 1
  ```sql
  21:54:01	select ... 1000 row(s) returned	0.625 sec / 0.328 sec
  ```

- 원인분석
  - 코로나 테이블과 프로그래머 테이블에 멤버 아이디에 대한 인덱스가 없어 풀테이블 스캔을 거치고 있었다. 인덱스를 추가해 주었다. 


- 적용
  - 인덱스를 추가했다
    ```sql
    CREATE INDEX `idx_covid_member_id`  ON `subway`.`covid` (member_id) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT
    CREATE INDEX `idx_programmer_member_id`  ON `subway`.`programmer` (member_id) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT
    ```
  - 이후 실행계획은 다음과 같다.   
    ```sql
    # id, select_type, table, partitions, type, possible_keys, key, key_len, ref, rows, filtered, Extra
    '1', 'SIMPLE', 'p', NULL, 'index', 'idx_programmer_member_id', 'idx_programmer_member_id', '9', NULL, '74465', '100.00', 'Using where; Using index'
    '1', 'SIMPLE', 'm', NULL, 'eq_ref', 'PRIMARY', 'PRIMARY', '8', 'subway.p.member_id', '1', '100.00', 'Using index'
    '1', 'SIMPLE', 'c', NULL, 'ref', 'idx_covid_member_id', 'idx_covid_member_id', '9', 'subway.p.member_id', '3', '100.00', 'Using where'
    '1', 'SIMPLE', 'h', NULL, 'eq_ref', 'PRIMARY', 'PRIMARY', '4', 'subway.c.hospital_id', '1', '100.00', 'Using where'
    ```
    ref, index full scan으로 개선된 모습을 볼 수 있다.

- 실행결과 2
  ```sql
  22:06:40	... 1000 row(s) returned	0.000 sec / 0.016 sec
  ```
  
  > 0ms < 100ms 이므로 성공!

### 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요.

- 쿼리
  ```sql
  SELECT p.id, h.name 
  FROM programmer p 
      inner join
          covid c on c.member_id = p.member_id
      inner join 
          hospital h on c.hospital_id = h.id
  where p.hobby = 'yes'
  or p.years_coding = '0-2 years'
  order by p.id
  ;
  ```
  
- 실행결과 1
  ```sql
  22:10:40	... 1000 row(s) returned	0.000 sec / 0.016 sec
  ```

- 원인 분석
  - explain 을 쳐보니 이미 기존의 인덱싱을 활용해 색인이 잘 되고 있다.
    ```sql
    # id, select_type, table, partitions, type, possible_keys, key, key_len, ref, rows, filtered, Extra
    '1', 'SIMPLE', 'p', NULL, 'index', 'idx_programmer_hobby,idx_programmer_member_id', 'PRIMARY', '8', NULL, '74465', '20.00', 'Using where'
    '1', 'SIMPLE', 'c', NULL, 'ref', 'idx_covid_member_id', 'idx_covid_member_id', '9', 'subway.p.member_id', '3', '100.00', 'Using where'
    '1', 'SIMPLE', 'h', NULL, 'eq_ref', 'PRIMARY', 'PRIMARY', '4', 'subway.c.hospital_id', '1', '100.00', 'Using where'
    ```
  > 0ms < 100ms 이므로 성공!
  
### 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. 

- 쿼리
  ```sql
  select c.stay, count(*)
  from programmer p
          inner join
      covid c
          on c.member_id = p.id and c.member_id is not null
          inner join
      member m 
          on m.id = p.member_id
          inner join
      hospital h
          on h.id = c.hospital_id
  where h.name = '서울대병원'
  and p.country = 'india'
  and m.age between 20 and 29
  group by c.stay
  ;
  ```

- 원인분석
  - 실행 계획부터 확인해보니, programmer 테이블이 full scan되고 있었다.
  
- 적용
  ```sql
  CREATE INDEX `idx_programmer_country`  ON `subway`.`programmer` (country) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT
  ```

- 실행결과 1
  - 프로그래머가 country 인덱스 기준으로 레인지 스캔을 하게 되었다.
  ```sql
  # id, select_type, table, partitions, type, possible_keys, key, key_len, ref, rows, filtered, Extra
  '1', 'SIMPLE', 'p', NULL, 'ref', 'PRIMARY,idx_programmer_country', 'idx_programmer_country', '1023', 'const', '26162', '100.00', 'Using index; Using temporary; Using filesort'
  ```
  ```sql
  23:57:52	select... 11 row(s) returned	0.062 sec / 0.000 sec
  ```
  > 62ms < 100ms 이므로 성공!

### 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. 
- 쿼리
  ```sql
  select count(p.exercise), p.exercise
  from covid c
      inner join hospital h
          on c.hospital_id = h.id and c.member_id is not null
      inner join programmer p
          on c.programmer_id = p.id
      inner join member m
          on p.member_id = m.id
  where m.age between 30 and 39
              and h.name = '서울대병원'
  group by p.exercise
  ```

- 실행결과 1
  ```sql
  00:07:25	select 5 row(s) returned	0.219 sec / 0.000 sec
  ```
  
- 원인 분석
  - covid 테이블이 table full scan을 하고 있었다. 
    
- 적용
  - covid.hospital_id와 covid.programmer_id 중 어떤 칼럼에 인덱스를 줄 지 고민했다.
  - covid내에서 hospital_id는 32 row지만 row별로 비슷한 분포를 보였다.
    ```sql
    select count(1) from covid group by hospital_id LIMIT 0, 1000
    ## 32 ROW, 아래는 조회 결과
    # count(1)
    '5249'
    '5102'
    '7116'
    '1240'
    '5261'
    ...
    ```
  - programmer_id는 10만 row이지만, 매우 편중된 분포를 보였다.
    ```sql
      select count(1) from covid group by programmer_id LIMIT 0, 1000
      ## 대략 10만 ROW , 아래는 조회 결과
      # count(1)
      '222145'
      '1'
      '1'
      '1'
      ...
    ```
  - 인덱싱 효과는 카디널리티가 분포가 고른 hospital_id가 높을 것이라고 판단했고, 인덱스를 주었다
    ```sql
    CREATE INDEX `idx_covid_hospital_id`  ON `subway`.`covid` (hospital_id) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT
    ```
  
  - 추가로 hospital도 table full scan을 하고 있지만, row수가 적고 hospital_name 칼럼이 text타입이라 인덱스론 부적합하여 인덱싱에서 제외하였다.
  - member.age 항목또한 추가로 인덱싱 하였다.
    ```sql
    CREATE INDEX `idx_member_age`  ON `subway`.`member` (age) COMMENT '' ALGORITHM DEFAULT LOCK DEFAULT
    ```

- 실행결과 2
  ```sql
  00:24:09	select ...	5 row(s) returned	0.063 sec / 0.000 sec
  ```
  
  > 63ms < 100ms 이므로 성공!
  
# 끝! 