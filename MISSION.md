# Mission 제출 답안

## A. 쿼리 연습
### [1. 쿼리 작성만으로 1s 이하로 반환한다]
- **결과**
    - [A 문제 쿼리 응답](https://github.com/PapimonLikelion/sql-tuning/blob/main/answer/a.txt)

- **다음과 같이 쿼리를 작성했어요**
    ```sql
    SELECT 사원.사원번호, 사원.이름, 부서관리자_급여.연봉, 직급.직급명, 사원출입기록.입출입시간, 사원출입기록.지역, 사원출입기록.입출입구분
    FROM (SELECT 부서관리자.사원번호, 급여.연봉
            FROM 부서관리자
                 JOIN 급여 ON 부서관리자.사원번호 = 급여.사원번호
            WHERE 부서관리자.부서번호 
                 IN (SELECT 부서번호 FROM 부서 WHERE 비고 = 'active') 
                 AND 부서관리자.종료일자 > NOW()
                 AND 급여.종료일자 > NOW()
            ORDER BY 급여.연봉 DESC 
            LIMIT 5) 부서관리자_급여 
        JOIN 사원
            ON 부서관리자_급여.사원번호 = 사원.사원번호
        JOIN 직급
            ON 부서관리자_급여.사원번호 = 직급.사원번호
        JOIN 사원출입기록
            ON 부서관리자_급여.사원번호 = 사원출입기록.사원번호
    WHERE
        직급.종료일자 > NOW() AND
        사원출입기록.입출입구분 = 'O'
    ORDER BY
        부서관리자_급여.연봉 DESC, 
        사원출입기록.지역;
    ```

- **다음과 같이 결과가 조회돼요**
    - 대략 0.3 sec가 소요됐어요
    - ![](./image/a-1-time.PNG)

- **실행계획은 다음과 같아요**
    - ![](./image/a-1-execution-plan.PNG)
    - ![](./image/a-1-execution-plan2.PNG)
    - where 절의 `사원출입기록.입출입구분 = 'O'` 가 테이블 풀 스캔으로 데이터 접근해요
    - order by 절의 `부서관리자_급여.연봉` 도 데이터 풀 스캔으로 데이터 접근해요
    - extra 칼럼에는 using index가 하나도 없어요
        - using temporary
        - using filesort
        - using where

### [2. 인덱스 설정을 추가하여 50 ms 이하로 반환한다]
- **일단 테이블 풀 스캔을 없애보기로 했어요**
    - ``create index `입출입구분` ON 사원출입기록 (입출입구분);``
    - 조금 줄어서 0.2sec 정도 소요
    - ![](./image/a-2-first-time.PNG)
    - 실행 계획을 보니 여전히 사원출입기록은 너무 많이 Row를 읽어와요
        - ![](./image/a-2-executaion-plan.PNG)

- **사원출입기록에 사원번호, 입출입구분 두 가지 칼럼에 대해 인덱스를 걸어보았어요**
    - ``drop index `입출입구분` ON 사원출입기록;``
    - ``create index `사원번호_입출입구분` ON 사원출입기록 (사원번호, 입출입구분);``
    - 시간이 많이 줄었어요
        - 대략 0.000sec ~ 0.015sec 정도로 계산되어요
        - ![](./image/a-2-second-time.PNG)
    - 실행계획에서도 사원출입기록에서 조회해오는 Row가 2개로 감소한 것을 확인할 수 있어요.
        - ![](./image/a-2-second-execution-plan.PNG)
        - ![](./image/a-2-second-execution-plan-graph.PNG)

### B. 인덱스 설계
### [1. Coding as a Hobby 와 같은 결과를 반환하세요.]
- **결과**
    - [B-1 문제 쿼리 응답](https://github.com/PapimonLikelion/sql-tuning/blob/main/answer/b-1.txt)

- **다음과 같은 값이 나와야 해요**
    - ![](./image/b-1-coding-hobby-stackoverflow.PNG)

- **다음과 같이 쿼리를 작성했어요**
    ``` sql
    SELECT
            CONCAT( CAST( ROUND((((SELECT COUNT(*) FROM programmer WHERE hobby = "Yes") / (SELECT COUNT(*) FROM programmer)) * 100), 1) AS CHAR(4)), "%") AS `Yes`,
            CONCAT( CAST( ROUND((((SELECT COUNT(*) FROM programmer WHERE hobby = "No") / (SELECT COUNT(*) FROM programmer)) * 100), 1) AS CHAR(4)), "%") AS `No`;  
    ```
    - 인덱스를 적용하지 않은 경우, 대략 650ms 갸량 소요되어요
        - ![](./image/b-1-before-index.PNG)

- **인덱스를 적용해볼게요**
    - 현재로서는 인덱스가 전혀 적용되어 있지 않아요
    - hobby와 id를 혼합하여 다중 컬럼 인덱스를 만들었어요
        - ``create index `hobby_id` on programmer (`hobby`, `id`);`` 
        - 사실 hobby가 yes/no로 만 나뉘어 카디널리티가 높지 않아서 효율성이 걱정됩니다
        - ![](./image/b-1-cardinality.PNG)
    - 인덱스 적용 후, 대략 80ms~90ms 정도 소요되어요
        - ![](./image/b-1-after-index.PNG)
    - 실행 계획도 인덱스를 사용하는 방식으로 변경되었어요
        - ![](./image/b-1-execution-plan.PNG)

### [2. 프로그래머별로 해당하는 병원 이름을 반환하세요. (covid.id, hospital.name)]
- **결과**
    - [B-2 문제 쿼리 응답](https://github.com/PapimonLikelion/sql-tuning/blob/main/answer/b-2.txt)

- **PK 부터 추가해볼게요**
    - PK가 Unique Key Lookup 이라 더 빠른걸 깜빡했어요. 
    - 모든 인덱스를 폐기하고 PK를 다음과 같이 추가했어요
    ```sql
    alter table covid add constraint primary key(id);
    alter table programmer add constraint primary key(id);
    alter table hospital add constraint primary key(id);
    ```

- **다음과 같이 쿼리를 작생했어요**
    ```sql
    SELECT shortenCovid.id AS `covid.id`, hospital.name AS `hospital.name`
    FROM hospital
        JOIN (SELECT hospital_id, id FROM covid WHERE programmer_id > 0) AS shortenCovid  
            ON hospital.id = shortenCovid.hospital_id;   
    ```

- **다음과 같은 인덱스를 추가했어요**
    ``` sql
    create index `programmer_id_hospital_id` on covid(`programmer_id`, `hospital_id`);
    ```
    - 실행계획은 다음과 같아요
        - ![](./image/b-2-after-index.PNG) 
    - 다음과 같은 결과가 나왔어요. duration_time이 0.000sec에요. 
        - (네트워크와 관련한 fetch time이 100ms 이하로 떨어져야 하는줄 알았답니다ㅜㅜ)
        - ![](./image/b-2-result.PNG)   

- **프로그래머 정보를 추가했어요**
    - 프로그래머ID 정보를 추가했어요. 
    ```SQL
    SELECT programmerInfo.id AS `programmer.id`, shortenCovid.id AS `covid.id`, hospital.name AS `hospital.name`
    FROM hospital
        JOIN (SELECT hospital_id, id, programmer_id FROM covid WHERE programmer_id > 0) AS shortenCovid  
            ON hospital.id = shortenCovid.hospital_id
        JOIN (SELECT id FROM programmer) AS programmerInfo
            ON shortenCovid.programmer_id = programmerInfo.id;   
    ```
    - 실행시간은 비슷하게 16ms 정도 소요되어요. 
        - ![](./image/b-2-after-feedback.PNG)
    - 실행계획은 다음과 같아요
        - ![](./image/b-2-after-feedback-execution-plan.PNG)

### [3. 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)]
- **결과**
    - [B-3 문제 쿼리 응답](https://github.com/PapimonLikelion/sql-tuning/blob/main/answer/b-3.txt)
    
- **다음과 같이 쿼리를 작성했어요**
    - 앞서 b-2에서 걸어둔 테이블의 pk는 유효해요
    ```sql    
    select covid.id AS `covid.id`, hospital.name AS `hospital.name`, junior_programmer.hobby AS `user.Hobby`, junior_programmer.dev_type AS `user.DevType`, junior_programmer.years_coding AS `user.YearsCoding`
        from (select id, hobby, dev_type, years_coding
            from programmer
            where (student like "Yes%" and hobby = "Yes") or years_coding = "0-2 years") AS junior_programmer
        join covid
            on junior_programmer.id = covid.programmer_id
        join hospital
            on covid.hospital_id = hospital.id;
    ```
    - 대략 0.016sec 가 소요되어요
        - ![](./image/b-3-before-index.PNG)
    - 실행 계획은 다음과 같아요
        - ![](./image/b-3-before-execution-plan.PNG)
    - 시간이 많이 소요되지 않았다고 판단해, 인덱스는 걸지 않기로 했어요

- **user.id 기준으로 order by를 걸어줄게요!**
    ```sql
    SELECT covid.id AS `covid.id`, hospital.name AS `hospital.name`, junior_programmer.hobby AS `user.Hobby`, junior_programmer.dev_type AS `user.DevType`, junior_programmer.years_coding AS `user.YearsCoding`
        FROM (SELECT id, hobby, dev_type, years_coding
            FROM programmer
            WHERE (student LIKE "Yes%" AND hobby = "Yes") OR years_coding = "0-2 years") AS junior_programmer
        JOIN covid
            ON junior_programmer.id = covid.programmer_id
        JOIN hospital
            ON covid.hospital_id = hospital.id
    ORDER BY junior_programmer.id;
    ```
    - 사실 duration은 16ms로 앞서 order by를 하기전과 같아요
        - ![](./image/b-3-after-feedback-time.PNG)
    - 실행계획을 보면 다음과 같아요
        - Order의 과정에서 filesort를 실행하거나 tmp_table등을 만들지 않아 앞서 정렬하지 않았던 쿼리랑 성능이 같았다고 보여요.
            - 가령 다른 필드 ex. ORDER BY programmer.hobby 등을 실행하면 filesort가 일어나거나 tmp_table을 만들거든요. 
        - 아마 programmer가 드라이빙 테이블로써 id 순으로 정렬된 상태로 계산했기 때문에 아니였을까 합니다!
        - ![](./image/b-3-after-feedback-execution.PNG)

### [4. 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)]
- **결과**
    - [B-4 문제 쿼리 응답](https://github.com/PapimonLikelion/sql-tuning/blob/main/answer/b-4.txt)
    
- **다음과 같이 쿼리를 작성했어요**
    ```sql
    select covid.stay, count(*) AS `인원수`
    from programmer 
        join member
            on programmer.member_id = member.id
        join covid
            on programmer.id = covid.programmer_id
        join hospital
            on hospital.id = covid.hospital_id
    where programmer.country = 'India'
        and (member.age >= 20 and member.age < 30)
        and hospital.name = '서울대병원'
    group by stay;
    ```
    - 대략 250ms 정도 소요 되어요
        - ![](./image/b-4-before-index.PNG)
    - 실행 계획은 다음과 같아요
        - ![](./image/b-4-execution-plan.PNG)

- **다음과 같이 인덱스를 적용했어요**
    - 기존의 programmer, covid, member, hospital에는 id에 PK 조건이 걸려있어요. 
    - covid 테이블에 member_id, programmer_id 에 unique 조건을 걸어줬어요
    - covid 테이블의 hospital에 index를 생성했어요
    - hospital 테이블의 name에 unique를 걸어줬어요
    - programmer 테이블의 member_id에 unique 조건을 걸어줬어요
    - member 테이블에 age에 대해 index를 생성했어요
    - programmer 테이블에 country에 대한 index를 생성했어요
    - 적용 후 대략 95~110ms 정도의 시간이 걸려요
        - ![](./image/b-4-after-index.PNG)
    - 실행 계획은 다음과 같아요
        - ![](./image/b-4-after-execution.PNG)    
        
- **더 줄어들지가 않네요...** 
    - stay에 인덱스를 걸어봐도, 
    - where절 대신 각 테이블 별 서브쿼리를 통해 가져오는 필드의 모수를 줄여봐도,
    - 마지막 group by에 tmp table, filesort가 안좋다고 판단해 order by null을 걸어도 (오히려 시간이 늘어나네요ㅜ),
    - 더 이상 시간이 단축되지 않아요ㅜㅜㅜ

- **구막의 피드백**
    - covid의 모수를 줄여서 가져오는 시도를 했으나,,, 95ms에서 더 줄지 않는군요 😭
    ```sql
    SELECT covid.stay, count(covid.stay) AS `인원수`
    FROM (SELECT programmer_id, hospital_id, member_id, stay FROM covid) AS covid
        JOIN (SELECT id FROM hospital WHERE name = '서울대병원') AS hospital
            ON hospital.id = covid.hospital_id
        JOIN (SELECT id FROM member WHERE age BETWEEN 20 AND 29) AS member
            ON member.id = covid.member_id
        JOIN (SELECT id FROM programmer WHERE country = 'India') AS programmer
            ON programmer.id = covid.programmer_id
    GROUP BY
        covid.stay;
    ```
        
### [5. 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)]
- **결과**
    - [B-5 문제 쿼리 응답](https://github.com/PapimonLikelion/sql-tuning/blob/main/answer/b-5.txt)
    
- **다음과 같이 쿼리를 작성했어요**
    ```sql
    select programmer.exercise, count(member.id)
    from programmer
        join covid
            on programmer.id = covid.programmer_id
        join member
            on programmer.member_id = member.id
        join hospital
            on covid.hospital_id = hospital.id
    where (member.age < 40 and member.age >= 30)
        and hospital.name = '서울대병원'
    group by programmer.exercise
    order by null;
    ```
    - 이미 b-4에서 제약조건을 걸어둔 필드를 많이 재사용을 많이 해서 그런가 약 94ms 정도 소요되었어요. 
        - ![](./image/b-5-before-index.PNG)
    - 실행계획은 다음과 같아요
        - ![](./image/b-5-execution-before.PNG)    

- **다음과 같은 인덱스를 적용했어요**
    - b-4에서의 제약조건/인덱스는 그대로 사용중이에요
    - covid 테이블에서 full table scan이 발생해요.
        - 따라서 hospital_id에 대해 인덱스를 생성해줬어요. 
    - 약 50ms로 시간이 단축되었어요. 
    - ![](./image/b-5-after-index.PNG)
    - 실행계획은 다음과 같아요
        - ![](./image/b-5-after-execution.PNG)
