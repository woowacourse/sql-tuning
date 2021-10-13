# 🚀 조회 성능 개선하기

## 생각해보기

![https://user-images.githubusercontent.com/48986787/136792017-52444d1d-6de2-42c8-8fd0-89b89f3bc22b.png](https://user-images.githubusercontent.com/48986787/136792017-52444d1d-6de2-42c8-8fd0-89b89f3bc22b.png)

## A. 쿼리 연습

### 실습환경 세팅

```
$ docker run -d -p 23306:3306 brainbackdoor/data-tuning:0.0.1
```

- [workbench](https://www.mysql.com/products/workbench/)를 설치한 후 localhost:23306 (ID : user, PW : password) 로 접속합니다.
1. 쿼리 작성만으로 1s 이하로 반환한다.
2. 인덱스 설정을 추가하여 50 ms 이하로 반환한다.
- [x]  활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)
- 급여 테이블의 사용여부 필드는 사용하지 않습니다. 현재 근무중인지 여부는 종료일자 필드로 판단해주세요.

![https://user-images.githubusercontent.com/48986787/136792075-39e09997-e57c-4f66-9b2f-7d7200474741.png](https://user-images.githubusercontent.com/48986787/136792075-39e09997-e57c-4f66-9b2f-7d7200474741.png)

### ERD 테이블 보기

테이블을 하나하나 살펴보기 힘드네요, Mysql에서 제공하는 ERD를 통해 확인해봐요. [ERD 자동생성](https://blog.naver.com/PostView.nhn?blogId=ajdkfl6445&logNo=221540488900&categoryNo=0&parentCategoryNo=0&viewDate=&currentPage=1&postListTopCurrentPage=1&from=postView)

![https://user-images.githubusercontent.com/48986787/136738094-3ded4729-5757-4d1f-8cb2-a0b0cef14af4.png](https://user-images.githubusercontent.com/48986787/136738094-3ded4729-5757-4d1f-8cb2-a0b0cef14af4.png)

생성된 DB의 ERD는 위와 같아요.

### 1. 쿼리 작성만으로 1s 이하로 반환한다.

**결과 쿼리**

```sql
SELECT `높은_연봉의_사원`.사원번호, `높은_연봉의_사원`.이름, `높은_연봉의_사원`.연봉, `높은_연봉의_사원`.직급명, 사원출입기록.입출입시간, 사원출입기록.지역, 사원출입기록.입출입구분
FROM (SELECT 사원.사원번호, 사원.이름, 급여.연봉, 직급.직급명
		FROM 사원
			JOIN 급여 ON 급여.사원번호 = 사원.사원번호
			JOIN 직급 ON 직급.사원번호 = 급여.사원번호
			JOIN 부서관리자 ON 부서관리자.사원번호 = 직급.사원번호
			JOIN 부서 ON 부서.부서번호 = 부서관리자.부서번호
		WHERE 급여.종료일자 = '9999-01-01' and 직급.종료일자 = '9999-01-01' 
			and 직급.직급명 = 'Manager' and 부서.비고 = 'active'
		ORDER BY 급여.연봉 desc 
		LIMIT 0,5) as `높은_연봉의_사원`
	JOIN 사원출입기록 ON 사원출입기록.사원번호 = `높은_연봉의_사원`.사원번호
WHERE 사원출입기록.입출입구분 = 'O' 
ORDER BY `높은_연봉의_사원`.연봉 desc, 사원출입기록.입출입시간 desc;
```

**결과 이미지** 

![https://user-images.githubusercontent.com/48986787/136782637-2e5764e9-3ab0-45bb-bdd6-99ab52ed0220.png](https://user-images.githubusercontent.com/48986787/136782637-2e5764e9-3ab0-45bb-bdd6-99ab52ed0220.png)

![https://user-images.githubusercontent.com/48986787/136782135-2260a571-a3bb-4631-903b-13474b924299.png](https://user-images.githubusercontent.com/48986787/136782135-2260a571-a3bb-4631-903b-13474b924299.png)

실행계획 (EXPLAIN)

![https://user-images.githubusercontent.com/48986787/136782251-aa684571-553b-4918-988a-8c92617ba414.png](https://user-images.githubusercontent.com/48986787/136782251-aa684571-553b-4918-988a-8c92617ba414.png)

**실행계획(WorkBench)**

![https://user-images.githubusercontent.com/48986787/136782549-d06ab5a4-92e1-4560-b8e3-fb89514c2eac.png](https://user-images.githubusercontent.com/48986787/136782549-d06ab5a4-92e1-4560-b8e3-fb89514c2eac.png)

### 2. 인덱스 설정을 추가하여 50 ms 이하로 반환한다.

**인덱스 추가 명령어**

```sql
CREATE INDEX `idx_사원_입출입구분_사원`  ON `tuning`.`사원출입기록` (사원번호,입출입구분);
```

하나의 인덱스를  추가했어요. 

**결과 이미지** 

![https://user-images.githubusercontent.com/48986787/136782637-2e5764e9-3ab0-45bb-bdd6-99ab52ed0220.png](https://user-images.githubusercontent.com/48986787/136782637-2e5764e9-3ab0-45bb-bdd6-99ab52ed0220.png)

![https://user-images.githubusercontent.com/48986787/136785462-6ae8183c-8beb-4b18-ba4f-962412f170c1.png](https://user-images.githubusercontent.com/48986787/136785462-6ae8183c-8beb-4b18-ba4f-962412f170c1.png)

**실행계획 (EXPLAIN)**

![https://user-images.githubusercontent.com/48986787/136788504-25004d7e-0a27-4995-8e9a-691ebbfc8e2f.png](https://user-images.githubusercontent.com/48986787/136788504-25004d7e-0a27-4995-8e9a-691ebbfc8e2f.png)

**실행계획(WorkBench)**

![https://user-images.githubusercontent.com/48986787/136788883-68d80d0a-74d2-4697-bb56-b88ffbc52493.png](https://user-images.githubusercontent.com/48986787/136788883-68d80d0a-74d2-4697-bb56-b88ffbc52493.png)

## B. 인덱스 설계

### 실습환경 세팅

```bash
$ docker run -d -p 13306:3306 brainbackdoor/data-subway:0.0.2
```

- [workbench](https://www.mysql.com/products/workbench/)를 설치한 후 localhost:13306 (ID : root, PW : masterpw) 로 접속합니다.

### ERD 테이블 보기

이것도 테이블을 하나하나 살펴보기 힘드네요, Mysql에서 제공하는 ERD를 통해 확인해봐요.

![https://user-images.githubusercontent.com/48986787/136790666-379c0aaa-c21a-41d3-968e-83e79e289b2a.png](https://user-images.githubusercontent.com/48986787/136790666-379c0aaa-c21a-41d3-968e-83e79e289b2a.png)

💉

### 요구사항

- [x]  주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환
    - [x]  [Coding as a Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.
        
        ### ~~제약조건~~
        
        ~~id, hobby 복합 제약조건, 설정~~ 
        
        ```sql
        ~~ALTER TABLE programmer ADD UNIQUE `id_hobby_unique` (id, hobby);~~
        ```
        
        ### **~~쿼리~~**
        
        ```sql
        ~~SELECT `yes` , `no`
        FROM (SELECT ROUND(COUNT(hobby)*100/(SELECT COUNT(hobby) FROM programmer) ,1) as `yes`
        		FROM programmer
        		WHERE hobby = 'Yes'
        ) as `YES`, 
        (SELECT ROUND(COUNT(hobby)*100/(SELECT COUNT(hobby) FROM programmer) ,1) as `no`
        		FROM programmer
        		WHERE hobby = 'No'
        ) as `NO`;~~
        ```
        
        ![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b6781671-49e1-4992-9a29-5662aead7301/Untitled.png)
        
        ![https://user-images.githubusercontent.com/48986787/136815843-e419168f-5a04-48bf-add7-1515bd6b7338.png](https://user-images.githubusercontent.com/48986787/136815843-e419168f-5a04-48bf-add7-1515bd6b7338.png)
        
        ![https://user-images.githubusercontent.com/48986787/136815769-ce96f5aa-168e-4ddf-abf7-6dd05b1999b6.png](https://user-images.githubusercontent.com/48986787/136815769-ce96f5aa-168e-4ddf-abf7-6dd05b1999b6.png)
        
        **~~실행계획 (EXPLAIN)~~**
        
        ![https://user-images.githubusercontent.com/48986787/136816057-f413478e-1282-4a99-9297-8def379bbd4f.png](https://user-images.githubusercontent.com/48986787/136816057-f413478e-1282-4a99-9297-8def379bbd4f.png)
        
        **~~실행계획 (Workbench)~~**
        
        ![https://user-images.githubusercontent.com/48986787/136816094-12b882bd-2658-460e-bca8-480ed2cd3953.png](https://user-images.githubusercontent.com/48986787/136816094-12b882bd-2658-460e-bca8-480ed2cd3953.png)
        
        > ~~아까워서 남겨보는 0.12 sec짜리의 쿼리..~~
        > 
        
        ```sql
        ~~SELECT hobby, ROUND(COUNT(hobby)*100/(SELECT COUNT(hobby) FROM programmer) ,1) as percentage
        FROM subway.programmer
        GROUP BY hobby
        ORDER BY hobby desc;~~
        ```
        
        ## 문제해결
        
        ### **쿼리**
        
        ```sql
        SELECT 
        	SUM(CASE WHEN hobby='Yes' THEN percentage ELSE 0 END) as Yes,
        	SUM(CASE WHEN hobby='No' THEN percentage ELSE 0 END) as No
        FROM ( 
        	SELECT hobby, ROUND(COUNT(hobby)*100/(SELECT COUNT(*) FROM programmer) ,1) as percentage FROM subway.programmer GROUP BY hobby ORDER BY null
        ) tb_derived;
        ```
        
        기존의 쿼리가 너무 마음에 들지않아. 위와 같이 쿼리를 변경했어요. 
        하지만 좁혀지지 않는 통곡의 0.1초대의 벽이 느껴졌어요. (0.11~2초의 저주)
        
        ![https://user-images.githubusercontent.com/48986787/137138204-1555180d-70b6-488d-96bc-384bf756d953.png](https://user-images.githubusercontent.com/48986787/137138204-1555180d-70b6-488d-96bc-384bf756d953.png)
        
        hobby의 카디널리티가 낮아, (id, unique) 복합유니크키를 유지했던 것이 문제였여요. 
        쿼리에서 복합 unique키중 하나인 hobby를 Group by를 하려하니, Using temporary, 즉 내부에 임시 테이블이 추가되며 속도 저하가 일어난게 화근이었네요. 
        인덱스가 아니기에 정렬됨을 보장하지 않아 생기는 문제였어요. 
        
        쿼리 상으로, 또한 실행계획상으로도 더이상 줄일 수 없다고 판단이 되어. 기존에 유지하던 방식을 버리기로 했어요. 
        
        ```sql
        DROP INDEX `id_hobby_unique`  ON `subway`.`programmer`;
        ```
        
        기존에 존재하던 UNIQUE 제약조건을 삭제하고, 
        
        ```sql
        CREATE INDEX `idx_programmer_hobby`  ON `subway`.`programmer` (hobby);
        ```
        
        hobby만 가지는 인덱스를 추가했어요. 
        
        ![https://user-images.githubusercontent.com/48986787/137142149-6d79a9b3-a9ae-415a-8fe0-55b7321ad505.png](https://user-images.githubusercontent.com/48986787/137142149-6d79a9b3-a9ae-415a-8fe0-55b7321ad505.png)
        
        **실행계획 (EXPLAIN)**
        
        ![https://user-images.githubusercontent.com/48986787/137142263-28afa97d-eb31-4baa-993f-a29903e84cac.png](https://user-images.githubusercontent.com/48986787/137142263-28afa97d-eb31-4baa-993f-a29903e84cac.png)
        
        **실행계획 (Workbench)**
        
        ![https://user-images.githubusercontent.com/48986787/137142304-dcc8f6ac-7101-43b3-ae6d-6101e17ddb32.png](https://user-images.githubusercontent.com/48986787/137142304-dcc8f6ac-7101-43b3-ae6d-6101e17ddb32.png)
        
        쿼리가 확실히 줄어둔 것을 확인할 수 있어요. 
        
    - [x]  프로그래머별로 해당하는 병원 이름을 반환하세요. (covid.id, hospital.name)
        
        ### 제약조건
        
        covid  id 컬럼 PK, UQ 제약조건 
        
        hospital id 컬럼 pk, UQ 제약조건, 
        
        programmer id 컬럼, pk, UQ 제약조건 
        
        ### **쿼리**
        
        ```sql
        SELECT covid.id as covid_id, hospital.name as hospital_name
        FROM subway.hospital
        JOIN covid ON covid.hospital_id = hospital.id
        JOIN programmer ON programmer.id  = covid.programmer_id;
        ```
        
        ![https://user-images.githubusercontent.com/48986787/136799255-214bb701-75f3-47dd-82c5-2cd182dc7d1b.png](https://user-images.githubusercontent.com/48986787/136799255-214bb701-75f3-47dd-82c5-2cd182dc7d1b.png)
        
        ![https://user-images.githubusercontent.com/48986787/136799345-c50ba69f-298b-4de1-8067-2d9789f79448.png](https://user-images.githubusercontent.com/48986787/136799345-c50ba69f-298b-4de1-8067-2d9789f79448.png)
        
        **실행계획 (EXPLAIN)**
        
        ![https://user-images.githubusercontent.com/48986787/136799539-d6d98960-602c-44be-ba72-c29fd389c62d.png](https://user-images.githubusercontent.com/48986787/136799539-d6d98960-602c-44be-ba72-c29fd389c62d.png)
        
        **실행계획 (Workbench)**
        
        ![https://user-images.githubusercontent.com/48986787/136799370-2e043dca-c6aa-4873-855d-2c4d1d03d390.png](https://user-images.githubusercontent.com/48986787/136799370-2e043dca-c6aa-4873-855d-2c4d1d03d390.png)
        
    - [x]  프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)
        
        ### ~~제약조건~~
        
        ~~인덱스 생성하지 않음.~~
        
        ### **~~쿼리~~**
        
        ```sql
        ~~SELECT 
            covid.id,
            hospital.name,
            user.Hobby,
            user.Dev_Type,
            user.Years_Coding,
            user.student
        FROM
            subway.covid
                JOIN
            hospital ON hospital.id = covid.hospital_id
                JOIN
            programmer AS user ON user.id = covid.programmer_id
        WHERE
            (user.hobby = 'Yes'
                AND user.student <> 'NO'
                AND user.student <> 'NA')
                OR (user.years_coding = '0-2 years')
        ;~~
        ```
        
        ![https://user-images.githubusercontent.com/48986787/136866681-88cea992-8a54-4496-9d0d-a2bddb526c53.png](https://user-images.githubusercontent.com/48986787/136866681-88cea992-8a54-4496-9d0d-a2bddb526c53.png)
        
        ![https://user-images.githubusercontent.com/48986787/136866711-15173e00-9791-4d8d-94c7-c66d22dd0127.png](https://user-images.githubusercontent.com/48986787/136866711-15173e00-9791-4d8d-94c7-c66d22dd0127.png)
        
        **~~실행계획 (EXPLAIN)~~**
        
        ![https://user-images.githubusercontent.com/48986787/136821094-ade65452-f169-404d-abe5-de6dd3c1fed4.png](https://user-images.githubusercontent.com/48986787/136821094-ade65452-f169-404d-abe5-de6dd3c1fed4.png)
        
        **~~실행계획 (Workbench)~~**
        
        ![https://user-images.githubusercontent.com/48986787/136866751-05e1adaa-7076-47a5-8e13-50ec2f12eca7.png](https://user-images.githubusercontent.com/48986787/136866751-05e1adaa-7076-47a5-8e13-50ec2f12eca7.png)
        
    
    ## 문제해결1
    
    ### **쿼리**
    
    ```sql
    SELECT C.id, H.name, P.Hobby, P.Dev_Type, P.Years_Coding, P.student
    FROM (SELECT id, hospital_id, programmer_id FROM subway.covid) AS C
    INNER JOIN (SELECT id, name FROM hospital) AS H ON H.id = C.hospital_id
    INNER JOIN (
    	SELECT id, Hobby, Dev_Type, Years_Coding, student FROM programmer 
        WHERE (hobby = 'Yes'
            AND student <> 'NO'
            AND student <> 'NA')
            OR (years_coding = '0-2 years')) AS P ON P.id = C.programmer_id
    ;
    ```
    
    전체 테이블에서 where 절을 거는 것이 마음에 들지 않았어요. FROM절에서 JOIN을 할때, 조건이 필요한 테이블은 조인 전 조건에 따라 분류해주면, 시간도 절약될 것이라 생각했어요.
    
    ![https://user-images.githubusercontent.com/48986787/137147909-d996dac7-e2df-4254-82ef-c5c195b98eb9.png](https://user-images.githubusercontent.com/48986787/137147909-d996dac7-e2df-4254-82ef-c5c195b98eb9.png)
    
    **0.026/sec**이 걸리던 쿼리가 **0.0085/sec**으로 3배가량 개선 됏네요! 
    
    **실행계획 (EXPLAIN)**
    
    ![https://user-images.githubusercontent.com/48986787/137148163-07870f73-5135-4ea9-a0bc-f175e5f33cb0.png](https://user-images.githubusercontent.com/48986787/137148163-07870f73-5135-4ea9-a0bc-f175e5f33cb0.png)
    
    **실행계획 (Workbench)**
    
    ![https://user-images.githubusercontent.com/48986787/137148215-2b8a2999-dba5-4faf-9899-76dd12c52f03.png](https://user-images.githubusercontent.com/48986787/137148215-2b8a2999-dba5-4faf-9899-76dd12c52f03.png)
    
    실행계획에서도 전반적인 cost가 감소한 것을 확인할 수 있네요! 
    
    ### 문제해결2 - hostpital의 name컬럼이 unique한가?에 대한 고찰.
    
    병원이름이 과연 겹칠까? 라고 생각을 했는데, 어쩌면 겹칠 수 있다고 생각해요. 사람 이름도 동일이름이 많은데 병원 이름도 분명 겹칠거에요 (수많은 "김내과"들..)
    hospital에 있던 name의 UNIQUE 속성을 제거했어요.
    
    ```sql
    DROP INDEX `name_UNIQUE`  ON `subway`.`hospital`;
    ```
    
    실행되는 쿼리도 차이가 없네요! ("마음대로 UNIQUE 속성을 정의하지 말자"를 배웠네요 ㅎㅎ)
    
    ![https://user-images.githubusercontent.com/48986787/137149699-f403f8ae-e32c-434e-a9fe-ab3ba3fc7f95.png](https://user-images.githubusercontent.com/48986787/137149699-f403f8ae-e32c-434e-a9fe-ab3ba3fc7f95.png)
    
    - [x]  서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)
        
        ### 제약조건
        
        member id PK, UQ 제약조건 
        
        covid stay 인덱싱 
        
        member  age 인덱싱
        
        programmer country 인덱싱 
        
        ### **쿼리**
        
        ```sql
        SELECT 
            stay, COUNT(stay)
        FROM (SELECT id FROM subway.member WHERE age BETWEEN 20 AND 29) AS M
        INNER JOIN (SELECT programmer_id, member_id, stay FROM covid) AS C ON C.member_id = M.id
        INNER JOIN (SELECT id, member_id FROM programmer WHERE country = 'India') AS P ON P.id = C.programmer_id
        GROUP BY stay;
        ```
        
        ![https://user-images.githubusercontent.com/48986787/136889997-91a14a22-541e-4698-9ad8-a85d5ac4bae9.png](https://user-images.githubusercontent.com/48986787/136889997-91a14a22-541e-4698-9ad8-a85d5ac4bae9.png)
        
        ![https://user-images.githubusercontent.com/48986787/136890046-c719a9a4-a478-4c89-8951-303ef76f8ca6.png](https://user-images.githubusercontent.com/48986787/136890046-c719a9a4-a478-4c89-8951-303ef76f8ca6.png)
        
        **실행계획 (EXPLAIN)**
        
        ![https://user-images.githubusercontent.com/48986787/136895290-a824cb05-0eb3-4f8f-b439-0bf60b56a17e.png](https://user-images.githubusercontent.com/48986787/136895290-a824cb05-0eb3-4f8f-b439-0bf60b56a17e.png)
        
        **실행계획(Workbench)**
        
        ![https://user-images.githubusercontent.com/48986787/136890106-555e9716-e260-464e-a912-be0b01bf8e25.png](https://user-images.githubusercontent.com/48986787/136890106-555e9716-e260-464e-a912-be0b01bf8e25.png)
        
    
    - [x]  서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)
        
        ### 제약조건
        
        covid hospital_id, member_id 인덱싱
        
        member  age 인덱싱
        
        hospital name 타입 VARCHAR(255)로 변경, name Unique 제약조건 설정 
        
        ### **쿼리**
        
        ```sql
        SELECT exercise, COUNT(exercise)
        FROM (SELECT id FROM subway.member WHERE age BETWEEN 30 AND 39) AS M
        INNER JOIN (SELECT id, member_id, hospital_id, programmer_id FROM covid) AS C ON C.member_id = M.id
        INNER JOIN (SELECT id, exercise FROM programmer) AS P ON P.id = C.programmer_id
        INNER JOIN (SELECT id, name FROM hospital WHERE name = '서울대병원') AS H ON H.id = C.hospital_id
        GROUP BY exercise;
        ```
        
        ![https://user-images.githubusercontent.com/48986787/136895512-4eb22980-f5b4-442f-9f10-b04d36689d03.png](https://user-images.githubusercontent.com/48986787/136895512-4eb22980-f5b4-442f-9f10-b04d36689d03.png)
        
        ![https://user-images.githubusercontent.com/48986787/136895596-54ac026e-b583-4b5b-a31c-f95ce4b125a7.png](https://user-images.githubusercontent.com/48986787/136895596-54ac026e-b583-4b5b-a31c-f95ce4b125a7.png)
        
        **실행계획 (EXPLAIN)**
        
        ![https://user-images.githubusercontent.com/48986787/136896714-38cc0cc7-df16-4544-8403-133b48a1e3a0.png](https://user-images.githubusercontent.com/48986787/136896714-38cc0cc7-df16-4544-8403-133b48a1e3a0.png)
        
        **실행계획(Workbench)**
        
        ![https://user-images.githubusercontent.com/48986787/136896788-e279b3a2-6f7c-4b94-bbbb-7f7cf58d9a42.png](https://user-images.githubusercontent.com/48986787/136896788-e279b3a2-6f7c-4b94-bbbb-7f7cf58d9a42.png)