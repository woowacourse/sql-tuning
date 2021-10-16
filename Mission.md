# SQL 미션

Property: October 9, 2021 8:44 PM

## A. 쿼리 연습

> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)
> 

### 1. 쿼리 작성만으로 1s 이하로 반환한다.

**쿼리**

```sql
SELECT 상위연봉사원.사원번호, 상위연봉사원.이름, 상위연봉사원.연봉, 상위연봉사원.직급명, 사원출입기록.입출입구분, 사원출입기록.입출입시간, 사원출입기록.지역
FROM 사원출입기록 
INNER JOIN (
	SELECT 사원.사원번호, 사원.이름, 급여.연봉, 직급.직급명
	FROM 사원 
	INNER JOIN 급여 ON 급여.사원번호 = 사원.사원번호
	INNER JOIN 직급 ON 직급.사원번호 = 사원.사원번호
	INNER JOIN 부서관리자 ON 직급.사원번호 = 부서관리자.사원번호
	INNER JOIN 부서 ON 부서관리자.부서번호 = 부서.부서번호
	WHERE 급여.종료일자 = "9999-01-01" AND 직급.종료일자 = "9999-01-01"
		AND LOWER(부서.비고) = "active" AND 부서관리자.종료일자 = "9999-01-01"
	ORDER BY 급여.연봉 DESC LIMIT 5
) 상위연봉사원 ON 사원출입기록.사원번호 = 상위연봉사원.사원번호
WHERE 사원출입기록.입출입구분 = "O"
ORDER BY 상위연봉사원.연봉 DESC, 사원출입기록.입출입시간 DESC;
```

**조회 결과**

![Untitled](SQL%20%E1%84%86%E1%85%B5%E1%84%89%E1%85%A7%E1%86%AB%20de89810ae6684782a6e2719f1ff6c208/Untitled.png)

![Untitled](SQL%20%E1%84%86%E1%85%B5%E1%84%89%E1%85%A7%E1%86%AB%20de89810ae6684782a6e2719f1ff6c208/Untitled%201.png)

**실행 계획** 

![Untitled](SQL%20%E1%84%86%E1%85%B5%E1%84%89%E1%85%A7%E1%86%AB%20de89810ae6684782a6e2719f1ff6c208/Untitled%202.png)

### 2. 인덱스 설정을 추가하여 50 ms 이하로 반환한다.

**인덱스 추가**

```sql
CREATE INDEX I_사원번호 ON 사원출입기록(사원번호);
```

- 조인 컬럼인 사원출입기록 테이블의 사원번호에 인덱스 생성
    - 한쪽에만 인덱스가 있을 경우, Join Buffer를 사용하여 성능 개선을 하나 일반적인 중첩 루프 조인에 비해 효율이 떨어지기 때문
    - 또한 테이블 크기와 상관없이 인덱스가 있는 테이블이 드라이빙 테이블이 되기 때문

**조회 결과**

![Untitled](SQL%20%E1%84%86%E1%85%B5%E1%84%89%E1%85%A7%E1%86%AB%20de89810ae6684782a6e2719f1ff6c208/Untitled.png)

**Duration**

![Untitled](SQL%20%E1%84%86%E1%85%B5%E1%84%89%E1%85%A7%E1%86%AB%20de89810ae6684782a6e2719f1ff6c208/Untitled%203.png)

**실행 계획** 

![Untitled](SQL%20%E1%84%86%E1%85%B5%E1%84%89%E1%85%A7%E1%86%AB%20de89810ae6684782a6e2719f1ff6c208/Untitled%204.png)

## B. 인덱스 설계

![Untitled](SQL%20%E1%84%86%E1%85%B5%E1%84%89%E1%85%A7%E1%86%AB%20de89810ae6684782a6e2719f1ff6c208/Untitled%205.png)

### 1. Coding as a Hobby 와 같은 결과를 반환하세요.

![Untitled](SQL%20%E1%84%86%E1%85%B5%E1%84%89%E1%85%A7%E1%86%AB%20de89810ae6684782a6e2719f1ff6c208/Untitled%206.png)

**쿼리**

```kotlin
SELECT 
ROUND(COUNT(CASE WHEN hobby = "Yes" THEN 1 END) / COUNT(*) * 100, 1) as Yes,
ROUND(COUNT(CASE WHEN hobby = "No"  THEN 1 END) / COUNT(*) * 100, 1) as No
FROM programmer;
```

**Duration**

![Untitled](SQL%20%E1%84%86%E1%85%B5%E1%84%89%E1%85%A7%E1%86%AB%20de89810ae6684782a6e2719f1ff6c208/Untitled%207.png)

**인덱스 추가**

```sql
ALTER TABLE `subway`.`programmer` 
CHANGE COLUMN `id` `id` BIGINT(20) NOT NULL ,
ADD PRIMARY KEY (`id`);
```

- id에 pk를 추가함으로써 자동으로 index가 추가되었음

![Untitled](SQL%20%E1%84%86%E1%85%B5%E1%84%89%E1%85%A7%E1%86%AB%20de89810ae6684782a6e2719f1ff6c208/Untitled%208.png)

![Untitled](SQL%20%E1%84%86%E1%85%B5%E1%84%89%E1%85%A7%E1%86%AB%20de89810ae6684782a6e2719f1ff6c208/Untitled%209.png)

- 아직까지는 Full Table Scan을 사용하고 있음

### 프로그래머별로 해당하는 병원 이름을 반환하세요. (covid.id, hospital.name)

```kotlin
SELECT covid.programmer_id, hospital.name
FROM covid 
INNER JOIN hospital ON hospital.id = covid.hospital_id
WHERE covid.programmer_id is not null
GROUP BY covid.programmer_id, hospital.name;
```

![Untitled](SQL%20%E1%84%86%E1%85%B5%E1%84%89%E1%85%A7%E1%86%AB%20de89810ae6684782a6e2719f1ff6c208/Untitled%2010.png)