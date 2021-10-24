

# A.쿼리연습

## 1. 쿼리 작성만으로 1s 이하로 반환한다.

```
활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요. (사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)
```


```SQL
SELECT 연봉TOP5.사원번호, 연봉TOP5.이름, 연봉TOP5.연봉, 연봉TOP5.직급명, 사원출입기록.지역, 사원출입기록.입출입구분, 사원출입기록.입출입시간 
FROM (
	SELECT 부서관리자.사원번호, 사원.이름, 급여.연봉, 직급.직급명
    FROM 부서관리자
    JOIN 사원 ON 부서관리자.사원번호 = 사원.사원번호
    JOIN 직급 ON 부서관리자.사원번호 = 직급.사원번호
    JOIN 부서 ON 부서관리자.부서번호 = 부서.부서번호
    JOIN 급여 ON 부서관리자.사원번호 = 급여.사원번호
    WHERE 부서관리자.종료일자 = '9999-01-01' AND 직급.종료일자 =  '9999-01-01' AND 급여.종료일자 = '9999-01-01' AND 부서.비고 = 'active'
    ORDER BY 급여.연봉 desc
    LIMIT 5
    ) AS 연봉TOP5
JOIN 사원출입기록 ON 연봉TOP5.사원번호 = 사원출입기록.사원번호
WHERE 사원출입기록.입출입구분 = 'O'
ORDER BY 연봉TOP5.연봉 DESC
```

![image](https://user-images.githubusercontent.com/18106839/138591142-0cd57220-1b81-4920-bff2-bba0f9622dff.png)

- 실행계획은 달라진게 없었다.

![image](https://user-images.githubusercontent.com/18106839/138591197-40d8e6cb-91eb-46c3-814b-76fed23925da.png)

![image](https://user-images.githubusercontent.com/18106839/138591218-22549689-0915-4f58-a385-d71a30790722.png)


### 실행계획

![image](https://user-images.githubusercontent.com/18106839/137380215-7dbfc293-e025-41d0-91a5-625a8e11c0d6.png)


![image](https://user-images.githubusercontent.com/18106839/137380249-815add01-5a49-45a5-8577-267f8f0cf045.png)



## 2. 인덱스 설정을 추가하여 50ms 이하로 반환한다.

- 실행 계획을 보면 사원출입기록에서 658935 rows에 접근하고 있다.
- 사원출입기록에서 사원번호와 입출입구분을 인덱스를 추가해준다.

![image](https://user-images.githubusercontent.com/18106839/137380322-e193fb95-0748-44ae-9e50-8d15bed942b3.png)



### 실행계획

![image](https://user-images.githubusercontent.com/18106839/137380343-efee1589-8000-494b-a92f-1aef760e0b88.png)

![image](https://user-images.githubusercontent.com/18106839/137380369-f99e8515-cea7-4110-8549-d37abe20b275.png)

![image](https://user-images.githubusercontent.com/18106839/137380407-741357c3-7400-4238-b0a0-8d7f78533e38.png)


### 지역별 최근 입출입시간을 조회하도록 변경

```
SELECT 연봉TOP5.사원번호, 연봉TOP5.이름, 연봉TOP5.연봉, 연봉TOP5.직급명, 사원출입기록.지역, 사원출입기록.입출입구분, MAX(사원출입기록.입출입시간) 
FROM (
	SELECT 부서관리자.사원번호, 사원.이름, 급여.연봉, 직급.직급명
    FROM 부서관리자
    JOIN 사원 ON 부서관리자.사원번호 = 사원.사원번호
    JOIN 직급 ON 부서관리자.사원번호 = 직급.사원번호
    JOIN 부서 ON 부서관리자.부서번호 = 부서.부서번호
    JOIN 급여 ON 부서관리자.사원번호 = 급여.사원번호
    WHERE 부서관리자.종료일자 = '9999-01-01' AND 직급.종료일자 =  '9999-01-01' AND 급여.종료일자 = '9999-01-01' AND 부서.비고 = 'active'
    ORDER BY 급여.연봉 desc
    LIMIT 5
    ) AS 연봉TOP5
JOIN 사원출입기록 ON 연봉TOP5.사원번호 = 사원출입기록.사원번호
WHERE 사원출입기록.입출입구분 = 'O'
GROUP BY 연봉TOP5.사원번호, 연봉TOP5.연봉, 연봉TOP5.직급명, 사원출입기록.지역
ORDER BY 연봉TOP5.연봉 DESC

```

# B. 인덱스 설계

- [x] 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환

- [x] [Coding as a Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.

```SQL
SELECT hobby, (COUNT(hobby) / (SELECT COUNT(hobby) FROM programmer)) * 100 AS percentage
FROM programmer 
GROUP BY hobby
ORDER BY percentage DESC
```

![image](https://user-images.githubusercontent.com/18106839/137380470-6c87c05a-2823-409c-aba6-ab3e1cc2d2f2.png)

### 실행계획

![image](https://user-images.githubusercontent.com/18106839/137380612-dca3b66a-07f7-4b38-913d-65736e2869e3.png)

![image](https://user-images.githubusercontent.com/18106839/137380642-bccee07e-99db-4331-a055-82a1d1741782.png)



```SQL
CREATE INDEX `idx_programmer_hobby` ON subway.programmer(hobby);
```



### 실행계획

![image](https://user-images.githubusercontent.com/18106839/137380668-bf22da42-aae0-48a7-86f5-d49605dacd42.png)

![image](https://user-images.githubusercontent.com/18106839/137380692-2b330dda-7b81-4939-b4ce-ee73f6f13686.png)

![image](https://user-images.githubusercontent.com/18106839/137380720-f114fa1b-c87b-4fad-b723-e485c4f6e879.png)

- Index Full Scan은 수직적 탐색없이 인덱스의 리프블록을 처음부터 끝까지 수평적으로 탐색하는 방식.
- Index Full Scan은 대개 데이터 검색을 위한 최적의 인덱스가 없을 때 차선으로 선택된다.
  - hobby의 경우 카드널리티가 2(YES or NO)이다.
- hobby 또한 좋은 인덱스라고 할 수 없는데 Table Full Scan보다 성능이 좋아졌다.

---

# 1번문제

- [x] 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환
- [x] 프로그래머별로 해당하는 병원 이름을 반환하세요. (covid.id, hospital.name)

```SQL
SELECT covid.id, hospital.name 
FROM covid
JOIN programmer ON covid.programmer_id = programmer.id
JOIN hospital ON covid.hospital_id = hospital.id
```

- 인덱스를 걸지 않으면 Lost Connection 됨

- 카드널리티가 좀 더 높은 programmer_id를 선두 컬럼으로 그 다음 hospital_id로 인덱스를 걸어주었다.

 ```SQL
CREATE INDEX `idx_covid_programmerId_hospitalId` ON subway.covid (programmer_id, hospital_id)
 ```

![image](https://user-images.githubusercontent.com/18106839/137380742-741907a2-e8eb-4275-a56c-08041f210a63.png)

### 실행계획

![image](https://user-images.githubusercontent.com/18106839/137380762-19be0081-2e94-4d4d-8d9a-4a08cf9ad051.png)

![image](https://user-images.githubusercontent.com/18106839/137380774-2881d6da-e2e0-4b8d-92ed-7803a136a4fb.png)



---

# 2번문제

- [x] 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환
- [x] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

```SQL
SELECT covid.id, hospital.name, programmer.hobby, programmer.dev_type, programmer.years_coding
FROM covid
JOIN programmer ON covid.programmer_id = programmer.id
JOIN hospital ON covid.hospital_id = hospital.id
WHERE (programmer.hobby = 'Yes' AND programmer.student LIKE 'Yes%') 
OR programmer.years_coding LIKE '0-2%'
```

![image](https://user-images.githubusercontent.com/18106839/137380822-ae69c1e1-6e5b-4843-99db-2877a55be77d.png)

- 이전에 걸어놓았던 아래 인덱스 덕분에 programmer_id로 정렬이 되었다.

```SQL
CREATE INDEX `idx_covid_programmerId_hospitalId` ON subway.covid (programmer_id, hospital_id)
```



### 실행계획

![image](https://user-images.githubusercontent.com/18106839/137380848-6137e7cd-5bfd-49d3-8426-85e23e2b5b5a.png)

![image](https://user-images.githubusercontent.com/18106839/137380868-4cbe045e-805a-43f7-81c6-9b9531ad1029.png)

---
# 3번문제


- [x] 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환
- [x] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

```SQL
SELECT covid.stay, count(member.id)
FROM covid
JOIN member ON covid.member_id = member.id
JOIN programmer ON covid.programmer_id = programmer.id
JOIN hospital ON covid.hospital_id = hospital.id
WHERE hospital.name = '서울대병원' AND programmer.country = 'India' AND member.age BETWEEN 20 AND 29
GROUP BY covid.stay
```

![image](https://user-images.githubusercontent.com/18106839/137380911-28362ead-98ae-4e41-a6b5-a1f74d25ef4b.png)

### 실행계획

![image](https://user-images.githubusercontent.com/18106839/137380926-be35b6d1-e537-4016-9648-cf0e6f66c2a9.png)

![image](https://user-images.githubusercontent.com/18106839/137380950-5fa28683-aa61-473c-803a-b61921180267.png)



### 적용된 인덱스

- Idx_covid_programmerId_hospitalId -> covid.programmer_id, covid.hospital_Id
- member 테이블 id primary key



```sql
CREATE INDEX `idx_programmer_country` ON subway.programmer (country);
```

![image](https://user-images.githubusercontent.com/18106839/137444073-5e20a91e-01b6-49e3-9b3e-6089e82046ab.png)

### 실행계획

![image](https://user-images.githubusercontent.com/18106839/137444103-aa2c27e9-10cc-425e-a4ce-31ee43231655.png)

![image](https://user-images.githubusercontent.com/18106839/137444131-9acb9fc6-8b27-4ae1-ae54-174a973e72e6.png)



### 적용된 인덱스

- Idx_programmer_country -> programmer.country 컬럼
- Idx_covid_programmerId_hospitalId -> covid.programmer_id, covid.hospital_Id
- member 테이블 id primary key



````SQL
 CREATE INDEX `idx_programmer_country` ON subway.programmer (id, country);
````

![image](https://user-images.githubusercontent.com/18106839/137444162-1a6b38a9-e862-453f-834e-40ec99d5f75f.png)



### 실행계획

![image](https://user-images.githubusercontent.com/18106839/137444196-a36f2ce0-3a0b-4e68-956c-3c8922e08de6.png)

![image](https://user-images.githubusercontent.com/18106839/137444226-a9cacd64-9da9-4cbc-9e02-65dde4cc7269.png)

- Non-Unique Key LookUp이 Index Range Scan으로 변경되었고 nested loop가 block nested loop으로 변경되었다. 
- rows는 더 늘었다.



### 적용된 인덱스

- Idx_programmer_country -> programmer.id, programmer.country 컬럼
- Idx_covid_programmerId_hospitalId -> covid.programmer_id, covid.hospital_Id
- member 테이블 id primary key

----
# 4번문제


- [x] 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환
- [x] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

```SQL
SELECT programmer.exercise, count(programmer_id)FROM covidJOIN member ON covid.member_id = member.id JOIN programmer ON covid.programmer_id = programmer.idJOIN hospital ON covid.hospital_id = hospital.idWHERE hospital.name = '서울대병원' AND member.age BETWEEN 30 AND 39GROUP BY programmer.exercise
```

![image](https://user-images.githubusercontent.com/18106839/137444264-0260d13b-015c-4cba-8bd9-1ba2c4e9524c.png)

### 실행계획

![image](https://user-images.githubusercontent.com/18106839/137444293-117cebfd-d5cd-402c-a1a4-320466d71502.png)

![image](https://user-images.githubusercontent.com/18106839/137444315-f4e0a2a2-a8b9-499c-b203-f9c31d86c267.png)



- covid의 Full Table Scan을 줄여야 할 것 같다.
- hospital_id를 통해 조인이 이루어지는데, 해당 id에 대한 인덱스가 없으므로 걸어보자.



```SQL
CREATE INDEX `idx_covid_hospitalId` ON subway.covid (hospital_id);
```

![image](https://user-images.githubusercontent.com/18106839/137444345-ed6643c1-2381-4a84-90c4-6c884f7d0b55.png)

### 실행계획

![image](https://user-images.githubusercontent.com/18106839/137444361-7d463b53-5104-4577-b02d-0d6a46308c8b.png)

![image](https://user-images.githubusercontent.com/18106839/137444378-9a1ea965-5a1c-405d-94c7-63134d15e986.png)



### 적용된 인덱스

- Idx_programmer_country -> programmer.id, programmer.country 컬럼
- Idx_covid_programmerId_hospitalId -> covid.programmer_id, covid.hospital_Id
- Idx_covid_hospitalId -> covid.hospital_Id
- member 테이블 id primary key

### EXCERCISE에 인덱스 걸어보기

- Idx_programmer_country -> programmer.id, programmer.country 컬럼
- Idx_programmer_excercise -> programmer.id, programmer.excercise 컬럼 (추가)
- Idx_programmer_country -> programmer.id, programmer.country 컬럼
- Idx_covid_programmerId_hospitalId -> covid.programmer_id, covid.hospital_Id
- Idx_covid_hospitalId -> covid.hospital_Id
- member 테이블 id primary key

![image](https://user-images.githubusercontent.com/18106839/138591599-acc59dcf-9023-46ea-bfab-0c570634785c.png)

![image](https://user-images.githubusercontent.com/18106839/138591619-c09a12d7-b5e2-4ab2-8dfd-a4bdd139e242.png)

- idx_programmer_id_country가 쓰인다.

- idx_programmer_id_country를 지우고 테스트

![image](https://user-images.githubusercontent.com/18106839/138591685-c5610463-dcb4-4db3-bd4d-5557f6f88b9b.png)

- 별 차이는 없지만 더 안정적으로 나오는 듯..?
![image](https://user-images.githubusercontent.com/18106839/138591705-e5bab8d6-609a-4b31-b203-9bbcc333e862.png)





