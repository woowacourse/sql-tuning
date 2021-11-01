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
        
        programmer hobby 인덱싱
        
        ### **쿼리**
        
        ```sql
        SELECT 
        	SUM(CASE WHEN hobby='Yes' THEN percentage ELSE 0 END) as Yes,
        	SUM(CASE WHEN hobby='No' THEN percentage ELSE 0 END) as No
        FROM ( 
        	SELECT hobby, ROUND(COUNT(hobby)*100/(SELECT COUNT(*) FROM programmer) ,1) as percentage FROM subway.programmer GROUP BY hobby ORDER BY null
        ) tb_derived;
        ```
        
        ![https://user-images.githubusercontent.com/48986787/137575175-385d78e7-7f34-4c1e-9b9c-c9354bc07019.png](https://user-images.githubusercontent.com/48986787/137575175-385d78e7-7f34-4c1e-9b9c-c9354bc07019.png)
        
        ![https://user-images.githubusercontent.com/48986787/137142149-6d79a9b3-a9ae-415a-8fe0-55b7321ad505.png](https://user-images.githubusercontent.com/48986787/137142149-6d79a9b3-a9ae-415a-8fe0-55b7321ad505.png)
        
        **실행계획 (EXPLAIN)**
        
        ![https://user-images.githubusercontent.com/48986787/137142263-28afa97d-eb31-4baa-993f-a29903e84cac.png](https://user-images.githubusercontent.com/48986787/137142263-28afa97d-eb31-4baa-993f-a29903e84cac.png)
        
        **실행계획 (Workbench)**
        
        ![https://user-images.githubusercontent.com/48986787/137142304-dcc8f6ac-7101-43b3-ae6d-6101e17ddb32.png](https://user-images.githubusercontent.com/48986787/137142304-dcc8f6ac-7101-43b3-ae6d-6101e17ddb32.png)
        
        쿼리가 확실히 줄어둔 것을 확인할 수 있어요. 
        
        ### 참고사항
        
        기존의 쿼리가 너무 마음에 들지않아. 위와 같이 쿼리를 변경했어요. 
        하지만 좁혀지지 않는 통곡의 0.1초대의 벽이 느껴졌어요. (0.11~2초의 저주)
        
        hobby의 카디널리티가 낮아(카디널리티 2, 선택도 0.5), (id, hobby) 복합유니크키를 유지했던 것이 문제였여요. 
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
        
        ### 제약조건
        
        없음
        
        ### **쿼리**
        
        ```sql
        SELECT C.id, H.name, P.Hobby, P.Dev_Type, P.Years_Coding, P.student
        FROM (SELECT id, Hobby, Dev_Type, Years_Coding, student FROM programmer 
            WHERE (hobby = 'Yes'
                AND student <> 'NO'
                AND student <> 'NA')
                OR (years_coding = '0-2 years')) AS P
        INNER JOIN covid AS C ON C.programmer_id = P.id
        INNER JOIN hospital AS H ON H.id = C.hospital_id	
        ;
        ```
        
        ![https://user-images.githubusercontent.com/48986787/137575439-f63ee5d3-d406-4e6c-9531-7d3b2de8758d.png](https://user-images.githubusercontent.com/48986787/137575439-f63ee5d3-d406-4e6c-9531-7d3b2de8758d.png)
        
        ![https://user-images.githubusercontent.com/48986787/137575448-4bccb8a4-ef4f-4570-831c-db02b77e57af.png](https://user-images.githubusercontent.com/48986787/137575448-4bccb8a4-ef4f-4570-831c-db02b77e57af.png)
        
        **실행계획 (EXPLAIN)**
        
        ![https://user-images.githubusercontent.com/48986787/137148163-07870f73-5135-4ea9-a0bc-f175e5f33cb0.png](https://user-images.githubusercontent.com/48986787/137148163-07870f73-5135-4ea9-a0bc-f175e5f33cb0.png)
        
        **실행계획 (Workbench)**
        
        ![https://user-images.githubusercontent.com/48986787/137575503-65d61c21-a8f3-4466-b0f7-f4ddc38b6d54.png](https://user-images.githubusercontent.com/48986787/137575503-65d61c21-a8f3-4466-b0f7-f4ddc38b6d54.png)
        
        ### 참고사항
        
        전체 테이블에서 where 절을 거는 것이 마음에 들지 않았어요. FROM절에서 JOIN을 할때, 조건이 필요한 테이블은 조인 전 조건에 따라 분류해주면, 시간도 절약될 것이라 생각했어요.
        
        covid에 programmer_id를 인덱싱하면, 실행계획읜 Query Cost가 줄어듭니다.
        
        ![https://user-images.githubusercontent.com/48986787/137148215-2b8a2999-dba5-4faf-9899-76dd12c52f03.png](https://user-images.githubusercontent.com/48986787/137148215-2b8a2999-dba5-4faf-9899-76dd12c52f03.png)
        
        하지만 실행시간에 있어서, 큰 차이점을 느끼지 못해 인덱싱을 하지 않았어요.
        이후 Query Cost가 중요하다면, programmer_id의 인덱싱을 고려해봐도 좋을 듯 합니다. 
        
        ### hostpital의 name컬럼이 unique한가?에 대한 고찰.
        
        병원이름이 과연 겹칠까? 라고 생각을 했는데, 어쩌면 겹칠 수 있다고 생각해요. 사람 이름도 동일이름이 많은데 병원 이름도 분명 겹칠거에요 (수많은 "김내과"들..)
        hospital에 있던 name의 UNIQUE 속성을 제거했어요.
        
        ```sql
        DROP INDEX `name_UNIQUE`  ON `subway`.`hospital`;
        ```
        
        실행되는 쿼리도 차이가 없네요! ("마음대로 UNIQUE 속성을 정의하지 말자"를 배웠네요 ㅎㅎ)
        
        ![https://user-images.githubusercontent.com/48986787/137149699-f403f8ae-e32c-434e-a9fe-ab3ba3fc7f95.png](https://user-images.githubusercontent.com/48986787/137149699-f403f8ae-e32c-434e-a9fe-ab3ba3fc7f95.png)
        
    - [x]  서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)
        
        ### 제약조건
        
        member id PK 제약조건 
        
        coivd  (hospital_id, member_id) 인덱싱
        
        ### **쿼리**
        
        ```sql
        SELECT stay, COUNT(stay)
        FROM (SELECT id FROM subway.member WHERE age BETWEEN 20 AND 29) AS M
        INNER JOIN covid AS C ON C.member_id = M.id
        INNER JOIN (SELECT id, member_id FROM programmer WHERE country = 'India') AS P ON P.id = C.programmer_id
        INNER JOIN (SELECT id, name FROM hospital WHERE name = '서울대병원') AS H ON H.id = C.hospital_id
        GROUP BY stay;
        ```
        
        ![https://user-images.githubusercontent.com/48986787/137574721-8dc21df8-5d01-4d7b-994c-abf2933e84be.png](https://user-images.githubusercontent.com/48986787/137574721-8dc21df8-5d01-4d7b-994c-abf2933e84be.png)
        
        ![https://user-images.githubusercontent.com/48986787/137574727-9ffa5a30-1e5d-4d31-ad0c-4d5a2a3115c8.png](https://user-images.githubusercontent.com/48986787/137574727-9ffa5a30-1e5d-4d31-ad0c-4d5a2a3115c8.png)
        
        **실행계획 (EXPLAIN)**
        
        ![https://user-images.githubusercontent.com/48986787/137574744-3e34844e-87c2-43d7-80ea-15043eb60f08.png](https://user-images.githubusercontent.com/48986787/137574744-3e34844e-87c2-43d7-80ea-15043eb60f08.png)
        
        **실행계획(Workbench)**
        
        ![https://user-images.githubusercontent.com/48986787/137574730-dd629a6e-7f23-42c0-b54f-75deb162e1a6.png](https://user-images.githubusercontent.com/48986787/137574730-dd629a6e-7f23-42c0-b54f-75deb162e1a6.png)
        
        ### 참고 사항
        
        covid 테이블의 hospital_id의 선택도(카디널리티)가 32로 나오고 있어요, 
        member_id는 95667로 나와서, 먼저 member_id로 인덱스를 잡았어요. (카디널리티가 높으면 좋다~ 라는 생각으로)
        하지만, 속도가 생각보다 좋게 나오지 않았어요. 
        그다음으로, 복합 인덱스를 구성하며 (member_id, hospital_id)로 인덱스를 잡았는데 이또한 생각보다 늦은 속도를 보여주기에,  (hospital_id, member_id)로 인덱스를 잡았습니다.
        복합 인덱스에서, 선행되는 테이블의 카디널리티가 너무 높으면, 그만큼 검색 비용이 더 들지 않을까 합니다 :) 
        
    - [x]  서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)
        
        ### 제약조건
        
        covid hospital_id, member_id 인덱싱
        
        ### **쿼리**
        
        ```sql
        SELECT P.exercise, COUNT(exercise)
        FROM (SELECT id FROM subway.member WHERE age BETWEEN 30 AND 39) AS M
        INNER JOIN covid AS C ON C.member_id = M.id
        INNER JOIN programmer AS P ON P.id = C.programmer_id
        INNER JOIN (SELECT id, name FROM hospital WHERE name = '서울대병원') AS H ON H.id = C.hospital_id
        GROUP BY P.exercise;
        ```
        
        ![https://user-images.githubusercontent.com/48986787/136895512-4eb22980-f5b4-442f-9f10-b04d36689d03.png](https://user-images.githubusercontent.com/48986787/136895512-4eb22980-f5b4-442f-9f10-b04d36689d03.png)
        
        ![https://user-images.githubusercontent.com/48986787/137574945-78c4b4df-f15a-4c2c-90af-9fc3cf0ee465.png](https://user-images.githubusercontent.com/48986787/137574945-78c4b4df-f15a-4c2c-90af-9fc3cf0ee465.png)
        
        **실행계획 (EXPLAIN)**
        
        ![https://user-images.githubusercontent.com/48986787/137574954-20fafc0f-f042-4622-a6a0-062268615d6b.png](https://user-images.githubusercontent.com/48986787/137574954-20fafc0f-f042-4622-a6a0-062268615d6b.png)
        
        **실행계획(Workbench)**
        
        ![https://user-images.githubusercontent.com/48986787/137574959-722b7c30-793f-49d1-8751-f5c214f2e839.png](https://user-images.githubusercontent.com/48986787/137574959-722b7c30-793f-49d1-8751-f5c214f2e839.png)
        
        ### 참고사항
        
        ORDER BY null을 통해,  실행계획 Extra의 filesort를 없앨 수는 있지만, 실행 속도의 차이가 크지 않았어요. 그룹화 된 exercise의 모수가 그렇게 크지 않아서 정렬을 하건, 하지 않던 차이가 없는듯 합니다.
        GROUP BY가 기본적으로 정렬을 하기에, 다른 옵션을 추가하지 않았어요.