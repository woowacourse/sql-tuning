# 🚀 조회 성능 개선하기

## A. 쿼리 연습
> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)

### 첫 번째 쿼리 작성 시도
```sql
SELECT
	고연봉관리자.사원번호 as 사원번호,
    고연봉관리자.이름 as 이름,
    고연봉관리자.연봉 as 연봉,
    고연봉관리자.직급명 as 직급명,
    사원출입기록.지역 as 지역,
    사원출입기록.입출입구분 as 입출입구,
    사원출입기록.입출입시간 as 입출입시간
FROM (
    SELECT 
		사원.사원번호,
        사원.이름,
        급여.연봉,
        직급.직급명
	FROM 
		부서
        JOIN 부서관리자 ON 부서.부서번호 = 부서관리자.부서번호
        JOIN 사원 ON 부서관리자.사원번호 = 사원.사원번호
        JOIN 직급 ON 부서관리자.사원번호 = 직급.사원번호
        JOIN 급여 ON 부서관리자.사원번호 = 급여.사원번호
	WHERE		
		  부서.비고='Active'
		  AND 부서관리자.시작일자 < CURDATE()
		  AND CURDATE() < 부서관리자.종료일자 
	ORDER BY
		급여.연봉 DESC
	LIMIT
		5
    ) AS 고연봉관리자 
    JOIN 사원출입기록 ON 고연봉관리자.사원번호 = 사원출입기록.사원번호
WHERE
	사원출입기록.입출입구분 = 'O'
ORDER BY
	고연봉관리자.연봉 DESC
;
```

동작은 하나, 아무런 결과가 조회되지 않았다.
서브쿼리 내부에서 문제가 발생하고 있는 것 같았다.

### 두 번째 쿼리 작성 시도

```sql
SELECT
	고연봉관리자.사원번호 as 사원번호,
    고연봉관리자.이름 as 이름,
    고연봉관리자.연봉 as 연봉,
    고연봉관리자.직급명 as 직급명,
    사원출입기록.지역 as 지역,
    사원출입기록.입출입구분 as 입출입구,
    사원출입기록.입출입시간 as 입출입시간
FROM (
    SELECT 
		사원.사원번호,
        사원.이름,
        급여.연봉,
        직급.직급명
	FROM 
		부서
        JOIN 부서관리자 ON 부서.부서번호 = 부서관리자.부서번호
        JOIN 사원 ON 부서관리자.사원번호 = 사원.사원번호
        JOIN 직급 ON 부서관리자.사원번호 = 직급.사원번호
        JOIN 급여 ON 부서관리자.사원번호 = 급여.사원번호
	WHERE		
		부서.비고='Active'
		AND CURDATE() BETWEEN 부서관리자.시작일자 AND 부서관리자.종료일자    
		AND CURDATE() BETWEEN 직급.시작일자 AND 직급.종료일자
		AND CURDATE() BETWEEN 급여.시작일자 AND 급여.종료일자
	ORDER BY
		급여.연봉 DESC
	LIMIT
		5
    ) AS 고연봉관리자 
    JOIN 사원출입기록 ON 고연봉관리자.사원번호 = 사원출입기록.사원번호
WHERE
	사원출입기록.입출입구분 = 'O'
ORDER BY
	고연봉관리자.연봉 DESC
;
```

서브 쿼리의 WHERE절 조건 '종료일자'가 너무 러프한거 같아서, 부서사원_매핑 테이블을 제외한 모든 테이블에서 사용되는 시작일자/종료일자를 제한조건으로 사용했다. 그러고 나니 원하는 결과를 얻을 수 있었다. 그러나 서브쿼리의 WHERE절에서 이루어지는 범위 탐색이 애매하다고 느껴졌다.

현재는 3개의 시작일자~종료일자 범위 탐색이 운이 좋게 맞아떨어져서 `Vishwani`, `Hauke`, `Isamu`, `Leon`, `Karsten` 5명이 집계된 것이고, 운이 나쁘면 중복된 사원이 집계될 수도 있었을거란 생각이 들었다. 

검프가 내부 데이터 조회를 도와준 덕분에 알아보니, 실제 내부 데이터에 시작일자~종료일자 가 겹치는 데이터가 존재하지 않았다. 때문에 BETWEEN을 이용한 WHERE 절에서 중복된 사원이 모두 제거된 것이었다. 그러나 "기간이 서로 겹치는 데이터가 존재하지 않을 것이라고 온전히 믿어도 될까?" 라는 의심 때문에 GROUP BY 절로 사원과 직급명을 묶고, 최대 급여.연봉 만 확인하도록 처리를 하려했다.

그러나 **CU께 "쿼리를 작성할 때, 내부 데이터를 신뢰하고 쿼리를 작성해야하나요?" 라는 질문을 드렸을 때 "그렇다." 라는 답변**을 받고 중복검증 쿼리 추가를 하지 않았다. 왜 내부 데이터를 신뢰하고 쿼리를 작성해야하는가?

내부 데이터를 신뢰하지 못하고 검증 관련 쿼리를 하나씩 추가하게 되면 점차 데이터베이스에 의존적인 형태로 쿼리가 작성되게 된다. 
데이터의 신뢰성이 떨어진다면 데이터 정제를 다시 수행하거나, 데이터가 데이터베이스로 전달되기 전 애플리케이션 레벨에서 검증 전처리를 확실하게 수행하는 것이 좋은 방향이다. (검증 쿼리가 추가되는 만큼 쿼리의 성능 이슈도 생길 수 있을거 같았는데, 그것보다 프로그램이 점점 데이터베이스에 의존적인 형태로 바뀌는게 가장 위험하다고 하셨다.)

최종적으로 아래 쿼리로 마무리 지었다.

```sql
SELECT
	고연봉관리자.사원번호 as 사원번호,
    고연봉관리자.이름 as 이름,
    고연봉관리자.연봉 as 연봉,
    고연봉관리자.직급명 as 직급명,
    사원출입기록.지역 as 지역,
    사원출입기록.입출입구분 as 입출입구,
    사원출입기록.입출입시간 as 입출입시간
FROM (
	SELECT 
		사원.사원번호,
		사원.이름,
		MAX(급여.연봉) AS 연봉,
		직급.직급명
	FROM 
		부서
		JOIN 부서관리자 ON 부서.부서번호 = 부서관리자.부서번호
		JOIN 사원 ON 부서관리자.사원번호 = 사원.사원번호
		JOIN 직급 ON 부서관리자.사원번호 = 직급.사원번호
		JOIN 급여 ON 부서관리자.사원번호 = 급여.사원번호
	WHERE		
		부서.비고='Active'
		AND CURDATE() BETWEEN 부서관리자.시작일자 AND 부서관리자.종료일자    
		AND CURDATE() BETWEEN 직급.시작일자 AND 직급.종료일자
		AND CURDATE() BETWEEN 급여.시작일자 AND 급여.종료일자 
	GROUP BY
		사원.사원번호, 직급.직급명
	ORDER BY
		MAX(급여.연봉) DESC
	LIMIT
		5
    ) AS 고연봉관리자 
    JOIN 사원출입기록 ON 고연봉관리자.사원번호 = 사원출입기록.사원번호
WHERE
	사원출입기록.입출입구분 = 'O'
ORDER BY
	고연봉관리자.연봉 DESC
;
```
| 사원번호 | 이름 | 연봉 | 직급명 | 지역 | 입출입구 | 입출입시간 |
|:--------:|:----:|:-----:|:-------:|:-----:|:-------:|:----------:|
| 110039 | Vishwani | 106491 | Manager | b | O | 2020-08-05 21:01:50 |
| 110039 | Vishwani | 106491 | Manager | d | O | 2020-07-06 11:00:25 |
| 110039 | Vishwani | 106491 | Manager | a | O | 2020-09-05 20:30:07 |
| 111133 | Hauke | 101987 | Manager | a | O | 2020-01-24 02:59:37 |
| 111133 | Hauke | 101987 | Manager | b | O | 2020-05-07 16:30:37 |
| 110114 | Isamu | 83457 | Manager | a | O | 2020-05-29 19:38:12 |
| 110114 | Isamu | 83457 | Manager | b | O | 2020-09-03 01:33:01 |
| 110114 | Isamu | 83457 | Manager | d | O | 2020-04-25 08:28:54 |
| 110114 | Isamu | 83457 | Manager | c | O | 2020-11-12 02:29:00 |
| 110567 | Leon | 74510 | Manager | a | O | 2020-10-17 19:13:31 |
| 110567 | Leon | 74510 | Manager | b | O | 2020-02-03 10:51:15 |
| 110228 | Karsten | 65400 | Manager | a | O | 2020-07-13 11:42:49 |
| 110228 | Karsten | 65400 | Manager | b | O | 2020-09-23 06:07:01 |
| 110228 | Karsten | 65400 | Manager | d | O | 2020-01-11 22:29:04 |

> 0.443 sec

### 쿼리 성능 최적화
![image](https://user-images.githubusercontent.com/37354145/137291146-db178d9f-8432-4940-abd4-f1beb9123633.png)

```
# id, select_type, table, partitions, type, possible_keys, key, key_len, ref, rows, filtered, Extra
'1', 'PRIMARY', '<derived2>', NULL, 'ALL', NULL, NULL, NULL, NULL, '2', '100.00', 'Using temporary; Using filesort'
'1', 'PRIMARY', '사원출입기록', NULL, 'ALL', NULL, NULL, NULL, NULL, '658935', '1.00', 'Using where; Using join buffer (Block Nested Loop)'
'2', 'DERIVED', '부서', NULL, 'ALL', 'PRIMARY', NULL, NULL, NULL, '9', '11.11', 'Using where; Using temporary; Using filesort'
'2', 'DERIVED', '부서관리자', NULL, 'ref', 'PRIMARY,I_부서번호', 'I_부서번호', '12', 'tuning.부서.부서번호', '2', '11.11', 'Using where'
'2', 'DERIVED', '직급', NULL, 'ref', 'PRIMARY', 'PRIMARY', '4', 'tuning.부서관리자.사원번호', '1', '11.11', 'Using where'
'2', 'DERIVED', '사원', NULL, 'eq_ref', 'PRIMARY', 'PRIMARY', '4', 'tuning.부서관리자.사원번호', '1', '100.00', NULL
'2', 'DERIVED', '급여', NULL, 'ref', 'PRIMARY', 'PRIMARY', '4', 'tuning.부서관리자.사원번호', '9', '11.11', 'Using where'
```

EXPLAIN 명령을 통해 실행 계획을 살펴보았을 때 `사원출입기록`에서 풀 스캔이 일어나며, 그 행 개수가 굉장히 많은 것을 확인할 수 있었다. 이 때문에 `사원출입기록`의 `사원번호`를 인덱싱 하는 것으로 성능을 개선하고자 했다.

```sql
CREATE INDEX idx_사원출입기록_사원번호 ON 사원출입기록 (사원번호);
```

그 후 조회 쿼리를 다시 수행했다.

| 사원번호 | 이름 | 연봉 | 직급명 | 지역 | 입출입구 | 입출입시간 |
|:--------:|:----:|:-----:|:-------:|:-----:|:-------:|:----------:|
| 110039 | Vishwani | 106491 | Manager | b | O | 2020-08-05 21:01:50 |
| 110039 | Vishwani | 106491 | Manager | d | O | 2020-07-06 11:00:25 |
| 110039 | Vishwani | 106491 | Manager | a | O | 2020-09-05 20:30:07 |
| 111133 | Hauke | 101987 | Manager | a | O | 2020-01-24 02:59:37 |
| 111133 | Hauke | 101987 | Manager | b | O | 2020-05-07 16:30:37 |
| 110114 | Isamu | 83457 | Manager | a | O | 2020-05-29 19:38:12 |
| 110114 | Isamu | 83457 | Manager | b | O | 2020-09-03 01:33:01 |
| 110114 | Isamu | 83457 | Manager | d | O | 2020-04-25 08:28:54 |
| 110114 | Isamu | 83457 | Manager | c | O | 2020-11-12 02:29:00 |
| 110567 | Leon | 74510 | Manager | a | O | 2020-10-17 19:13:31 |
| 110567 | Leon | 74510 | Manager | b | O | 2020-02-03 10:51:15 |
| 110228 | Karsten | 65400 | Manager | a | O | 2020-07-13 11:42:49 |
| 110228 | Karsten | 65400 | Manager | b | O | 2020-09-23 06:07:01 |
| 110228 | Karsten | 65400 | Manager | d | O | 2020-01-11 22:29:04 |

> 0.0031 sec

![image](https://user-images.githubusercontent.com/37354145/137292141-890d47c5-79dd-4b26-b557-4fb4c8937344.png)


인덱싱 후에도 여전히 풀스캔이 발생하나, 실제 데이터 조회는 9개 행만 이루어졌다. 
이에 따라 결과 조회 속도가 `0.0031 sec`로 개선되었다.

<br>

## B. 인덱스 설계

> 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환

## B-1. [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.

### 쿼리 작성
```sql
SELECT
	hobby,
    ROUND(COUNT(hobby) / total.hobby_count * 100, 1) AS percent
FROM
	programmer
    JOIN (
		SELECT
			COUNT(hobby) AS hobby_count
		FROM
			programmer
    ) AS total
GROUP BY
	hobby,
    hobby_count
;
```
```
# hobby, percent
'No', '19.2'
'Yes', '80.8'

2.660 sec
```

서브쿼리를 이용해 프로그래머들의 전체 프로그래밍 취미 응답 개수를 카운팅하고, 
YES/NO로 나누어진 취미 응답을 전체 개수로 나눈 뒤 x100, ROUND 함수를 이용해 소수점 1자리까지 반올림했다.

### 쿼리 성능 최적화
![image](https://user-images.githubusercontent.com/37354145/137465396-2d6a6a9b-f916-4695-a417-2b51c8689b32.png)

전체 프로그래머들의 응답 개수를 구해야하기 때문에 programmer 테이블의 풀 스캔이 발생하는 건 어쩔 수 없다고 생각했다. 
결국 관건은 hobby 내용에 대한 것인데, hobby 내용에 대한 인덱싱을 진행하면 속도가 크게 개선될 것으로 예측했다.

```sql
CREATE INDEX `idx_programmer_hobby` ON `subway`.`programmer` (hobby);
```
```
0.084 sec
```

또한 [MySQL 8.0 문서](https://dev.mysql.com/doc/refman/8.0/en/primary-key-optimization.html#:~:text=It%20has%20an%20associated%20index%2C%20for%20fast%20query%20performance)를 참고해보니 PK 설정을 통해 성능 개선이 이루어질 수도 있다는 것 같아 PK가 부여되어 있지 않은 모든 테이블에 PK를 부여했다.

```sql
ALTER TABLE 
	`subway`.`programmer` 
CHANGE COLUMN 
	`id` `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
	ADD PRIMARY KEY (`id`)
;
```
```
0.051 sec
```

실제로 성능 개선이 일어났다!

![image](https://user-images.githubusercontent.com/37354145/137471646-02097488-128e-4d77-85ad-4db209e84022.png)

그러나 PK를 부여한 이후 programmer 테이블 스캔시 row 개수가 71,000개에서 77,000개로 증가했다. 
'왜 증가한 것인지?', 'row 개수 증가에 따라 query cost가 증가했음에도 속도는 더 빨라진 이유가 무엇인지?'
는 조사가 더 필요할 것 같다.

### cross join 제거
인비로부터 ['ON 조건 없이 JOIN을 수행할 경우 CROSS JOIN이 된다'](https://stackoverflow.com/questions/16470942/how-to-use-mysql-join-without-on-condition/16471286) 라는 이야기를 듣고 
CROSS JOIN을 제거하도록 쿼리를 수정해보았다.

```sql
SELECT
	hobby,
    ROUND(COUNT(hobby) / (SELECT count(*) FROM .programmer) * 100, 1) AS percent
FROM
	programmer
GROUP BY
	hobby
;
```
```
0.051 sec
```
![image](https://user-images.githubusercontent.com/37354145/137477321-3fe6d945-1916-4cb4-a6e7-1a8ec883befa.png)

duration에는 드라마틱한 변화가 없었지만, 그래프가 조금 더 간결해졌다!

<br>

## B-2. 각 프로그래머별로 해당하는 병원 이름을 반환하세요. 
```sql
SELECT
	programmer_id,
    hospital_id,
    hospital.name AS hospital_name
FROM
	hospital
    JOIN covid ON hospital.id = covid.hospital_id
    JOIN programmer ON covid.programmer_id = programmer.id
;
```
```
# programmer_id, hospital_id, hospital_name
'1', '8', '고려대병원'
'2', '2', '분당서울대병원'
'3', '10', '경희대병원'
'4', '26', '우리들병원'
'5', '26', '우리들병원'
'7', '32', '국립암센터'
'8', '23', '강남성심병원'
'9', '1', '세브란스병원'
'10', '10', '경희대병원'
'11', '22', '한양대병원'
'12', '26', '우리들병원'
'13', '16', '이화여대병원'
... (생략) ...

0.0023 sec
```

![image](https://user-images.githubusercontent.com/37354145/137479385-9faef8d4-e522-4ee5-8003-7ea54f6187b6.png)

id에 대해 Primary Key를 부여해둔 덕분일까? Unique Key Lookup 조회로 빠른 결과를 얻을 수 있었다.

<br>

## B-3. 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. 
- '프로그래밍이 취미인 학생' 혹은 '주니어' 
- 프로그래밍이 취미인 '학생' 혹은 '주니어'

2가지 해석 방법이 있었다. 2가지 모두 해보았다.

### B-3-1. '프로그래밍이 취미인 학생' 혹은 '주니어'
```sql
SELECT
	programmer_id,
    hospital_id,
    hospital.name AS hospital_name
FROM
	hospital
    JOIN covid ON hospital.id = covid.hospital_id
    JOIN (
		SELECT
			id
		FROM
			programmer
		WHERE
			(hobby = 'Yes' AND dev_type LIKE '%Student%')
            OR (years_coding = '0-2 years' AND dev_type LIKE '%Developer%')
		) AS student_or_junior ON covid.programmer_id = student_or_junior.id
ORDER BY
	programmer_id
;
```
```
# programmer_id, hospital_id, hospital_name
'5', '26', '우리들병원'
'8', '23', '강남성심병원'
'12', '26', '우리들병원'
'13', '16', '이화여대병원'
'20', '12', '중앙대병원'
'39', '32', '국립암센터'
'41', '26', '우리들병원'
'42', '27', '을지병원'
'58', '6', '아주대학병원'
'61', '31', '인천백병원'
'70', '31', '인천백병원'
'81', '15', '고려대 구로병원'
'87', '32', '국립암센터'
'90', '19', '여의도성모병원'
... (생략) ...

0.207 sec
```

![image](https://user-images.githubusercontent.com/37354145/137484702-06c8f22d-b5f0-4056-9163-9df8bda60250.png)

Primary Key가 모두 인덱싱이 되어 있었기 때문에 Unique Key Lookup이 되었으나, 
`ORDER BY`절에 의해서 Duration 속도가 굉장히 떨어졌다.

그러던 중, **인덱스는 항상 정렬 상태를 유지하므로 인덱스 순서에 따라 ORDER BY, GROUP BY를 위한 소트 연산을 생략할 수 있다**는 이야기가 떠올라 `ORDER BY`절을 제거했다.

```sql
SELECT
	programmer_id,
    hospital_id,
    hospital.name AS hospital_name
FROM
	hospital
    JOIN covid ON hospital.id = covid.hospital_id
    JOIN (
		SELECT
			id
		FROM
			programmer
		WHERE
			(hobby = 'Yes' AND dev_type LIKE '%Student%')
            OR (years_coding = '0-2 years' AND dev_type LIKE '%Developer%')
		) AS student_or_junior ON covid.programmer_id = student_or_junior.id
;
```

![image](https://user-images.githubusercontent.com/37354145/137485020-510a369f-3755-4b7c-b7cd-a264cad64220.png)

```
0.056 sec
```

정렬이 제거되어 큰 성능 개선을 맛볼 수 있었다!

### B-3-2. 프로그래밍이 취미인 '학생' 혹은 '주니어'
```sql
SELECT
	programmer_id,
    hospital_id,
    hospital.name AS hospital_name
FROM
	hospital
    JOIN covid ON hospital.id = covid.hospital_id
    JOIN (
		SELECT
			id
		FROM
			programmer
		WHERE
			hobby = 'Yes'
            AND (
				dev_type LIKE '%Student%'
                OR (
					years_coding = '0-2 years' AND dev_type LIKE '%Developer%'
				)
			)
		) AS student_or_junior ON covid.programmer_id = student_or_junior.id
;
```
```
# programmer_id, hospital_id, hospital_name
'5', '26', '우리들병원'
'8', '23', '강남성심병원'
'12', '26', '우리들병원'
'13', '16', '이화여대병원'
'20', '12', '중앙대병원'
'39', '32', '국립암센터'
'41', '26', '우리들병원'
'42', '27', '을지병원'
'58', '6', '아주대학병원'
'61', '31', '인천백병원'
'70', '31', '인천백병원'
'81', '15', '고려대 구로병원'
'87', '32', '국립암센터'
'90', '19', '여의도성모병원'
... (생략) ...

0.065 sec
```

![image](https://user-images.githubusercontent.com/37354145/137485393-09937c1f-3c7d-45c1-b190-399cc7052d8e.png)

이전 풀이법보다 0.01 sec 정도 느린 결과를 얻을 수 있었다.

<br>

## B-4. 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요.
### 쿼리 작성
```sql
SELECT
	stay,
    COUNT(stay) AS india_patients_count
FROM
	covid
    JOIN (
		SELECT
			id
		FROM
			hospital
		WHERE
			name = '서울대병원'
    ) AS seoul_national_univ_hospital ON hospital_id = seoul_national_univ_hospital.id
    JOIN (
		SELECT
			id
		FROM
			member
		WHERE
			age BETWEEN 20 AND 29
	) AS twenties ON member_id = twenties.id
    JOIN (
		SELECT
			id
		FROM
			programmer
		WHERE
			country = 'India'
    ) AS indian ON programmer_id = indian.id
GROUP BY
	stay
;
```
```
# stay, india_patients_count
'0-10', '3'
'11-20', '25'
'21-30', '30'
'31-40', '18'
'41-50', '2'
'51-60', '17'
'71-80', '6'
'81-90', '1'
'91-100', '1'
'More than 100 Days', '2'

0.319 sec
```
![image](https://user-images.githubusercontent.com/37354145/137489191-30e1410e-83b5-4683-9f14-c060ee371b05.png)

### 쿼리 성능 최적화
`hospital` 테이블을 조회할 때 발생하는 풀 스캔부터 제거하기 위해
`hospital.name` 인덱싱을 진행하고자 했다.

```sql
CREATE INDEX `idx_hospital_name` ON `subway`.`hospital` (name);
```
```
Error Code: 1170. BLOB/TEXT column 'name' used in key specification without a key length
```

그러나 `name` 컬럼의 TEXT 타입은 인덱싱이 불가능했다. 때문에 `name` 컬럼을 VARCHAR 타입으로 변경하고 인덱싱을 다시 진행했다.

```sql
ALTER TABLE `subway`.`hospital` 
CHANGE COLUMN `name` `name` VARCHAR(255) NULL DEFAULT NULL ;
```
```sql
CREATE INDEX `idx_hospital_name` ON `subway`.`hospital` (name);
```
```
0.263 sec
```
![image](https://user-images.githubusercontent.com/37354145/137490264-3167f99e-d7f5-4052-a81d-3bafb3f41d38.png)

다음으로 `covid ` 테이블에서 발생하는 풀 스캔 제거를 위해 인덱싱을 진행했다.

```sql
CREATE INDEX `idx_covid_hospital_id_member_id_programmer_id` ON `subway`.`covid` (hospital_id, member_id, programmer_id);
```
```
0.121 sec
```
![image](https://user-images.githubusercontent.com/37354145/137490743-53b757e6-ad85-4bff-bef0-3bb5bd5a78cb.png)

풀 스캔은 모두 사라졌으나 여전히 속도가 0.1 sec를 넘기고 있었다. 
더 명확한 이유를 찾아보기 위해 EXPLAIN 쿼리 조회를 시도했다.

```
# id, select_type, table, partitions, type, possible_keys, key, key_len, ref, rows, filtered, Extra
'1', 'SIMPLE', 'hospital', NULL, 'ref', 'PRIMARY,idx_hospital_name', 'idx_hospital_name', '1023', 'const', '1', '100.00', 'Using index; Using temporary; Using filesort'
'1', 'SIMPLE', 'covid', NULL, 'ref', 'idx_covid_hospital_id_member_id_programmer_id', 'idx_covid_hospital_id_member_id_programmer_id', '9', 'func', '10177', '100.00', 'Using index condition'
'1', 'SIMPLE', 'programmer', NULL, 'eq_ref', 'PRIMARY', 'PRIMARY', '8', 'subway.covid.programmer_id', '1', '10.00', 'Using where'
'1', 'SIMPLE', 'member', NULL, 'eq_ref', 'PRIMARY', 'PRIMARY', '8', 'subway.covid.member_id', '1', '11.11', 'Using where'

```

`member` 테이블과 `programmer` 테이블을 조회하는데 where 절을 사용하고 있기 때문에 성능상 개선이 부족하다고 판단했다.

```sql
CREATE INDEX `idx_member_age` ON `subway`.`member` (age);
CREATE INDEX `idx_programmer_country` ON `subway`.`programmer` (country);
```
```
0.097 sec
```

그러나 여전히 만족스러운 성능 개선을 얻지 못했다. 무엇이 문제일까 고민하다가 
JOIN 단계에서 `covid` 테이블에 존재하는 다른 컬럼들까지 모두 조회하기 때문에 
성능 개선이 더딘게 아닐까 의심하게 되었다. 때문에 쿼리를 수정해보았다.

```sql
SELECT
	covid.stay AS stay,
    COUNT(covid.stay) AS india_patients_count
FROM
	(
		SELECT 
            hospital_id,
            member_id,
            programmer_id,
            stay
		FROM
			covid
    ) AS covid
    JOIN (
		SELECT
			id
		FROM
			hospital
		WHERE
			name = '서울대병원'
    ) AS seoul_national_univ_hospital ON covid.hospital_id = seoul_national_univ_hospital.id
    JOIN (
		SELECT
			id
		FROM
			member
		WHERE
			age BETWEEN 20 AND 29
	) AS twenties ON covid.member_id = twenties.id
    JOIN (
		SELECT
			id
		FROM
			programmer
		WHERE
			country = 'India'
    ) AS indian ON covid.programmer_id = indian.id
GROUP BY
	stay
;
```
```
0.038 sec
```

`covid` 테이블 관련 쿼리를 수정한 후 만족스러운 결과를 얻을 수 있었다.
그러나 동일한 쿼리를 이용해서 여러차례 조회를 시도하면 0.033 ~ 0.096 sec 까지 
편차가 큰 duration 결과를 보여주었다. 추가적인 고민이 필요할 것 같다.

<br>
