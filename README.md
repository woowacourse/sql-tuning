# 🚀 조회 성능 개선하기

## A. 쿼리 연습

### * 요구 사항

- 쿼리 작성만으로 1s 이하로 반환한다.
- 인덱스 설정을 추가하여 50 ms 이하로 반환한다.
- 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)
- 급여 테이블의 사용여부 필드는 사용하지 않습니다. 현재 근무중인지 여부는 종료일자 필드로 판단해주세요.

<div style="line-height:1em"><br style="clear:both" ></div>


### * 풀이 과정

**1. 쿼리 작성만으로 1s 이하로 반환한다.**

```sql
# 활동중인 부서
EXPLAIN
SELECT *
FROM 부서
WHERE UPPER(부서.비고) = 'ACTIVE';

EXPLAIN
SELECT *
FROM 부서
WHERE 부서.비고 = 'ACTIVE' OR 부서.비고 = 'aCTIVE' OR 부서.비고 = 'active';
```

```sql
# 특정 부서의 부서 관리자들 총 조회
SELECT *
FROM 부서관리자
JOIN (SELECT *
	FROM 부서
	WHERE 부서.비고 = 'ACTIVE' OR 부서.비고 = 'aCTIVE' OR 부서.비고 = 'active'
) as 활동부서
ON 활동부서.부서번호 = 부서관리자.부서번호;
```

```sql
# 특정 부서의 부서 관리자들 총 조회 + 연봉 출력
SELECT 부서관리자.사원번호, 사원.이름, 급여.연봉, 
	직급.직급명, 사원출입기록.지역, 사원출입기록.입출입구분, 사원출입기록.입출입시간
FROM 부서관리자
JOIN (SELECT *
	FROM 부서
	WHERE 부서.비고 = 'ACTIVE' OR 부서.비고 = 'aCTIVE' OR 부서.비고 = 'active'
) as 활동부서
ON 활동부서.부서번호 = 부서관리자.부서번호
JOIN 급여
ON 급여.사원번호 = 부서관리자.사원번호
JOIN 사원출입기록
ON 부서관리자.사원번호 = 사원출입기록.사원번호
JOIN 사원
ON 사원.사원번호 = 부서관리자.사원번호
JOIN 직급
ON 사원.사원번호 = 직급.사원번호
ORDER BY 연봉 DESC;
```

```sql
# 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위 안에 드는 사람들
SELECT 사원.사원번호, 사원.이름, 급여.연봉
FROM 부서관리자
JOIN (SELECT *
	FROM 부서
	WHERE 부서.비고 = 'ACTIVE' OR 부서.비고 = 'aCTIVE' OR 부서.비고 = 'active'
) as 활동부서
ON 활동부서.부서번호 = 부서관리자.부서번호

JOIN 급여
ON 급여.사원번호 = 부서관리자.사원번호

JOIN 사원
ON 사원.사원번호 = 부서관리자.사원번호
WHERE 급여.종료일자 > now()
AND 부서관리자.종료일자 > now()

ORDER BY 급여.연봉 DESC
LIMIT 5;
```

```sql
# '활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위 안에 드는 사람들'이 
# 최근에 각 지역별로 언제 퇴실했는지 조회해보기
SELECT tb.사원번호, tb.이름, tb.연봉, 직급.직급명, 사원출입기록.입출입시간, 사원출입기록.지역, 사원출입기록.입출입구분
FROM (
	SELECT 사원.사원번호, 사원.이름, 급여.연봉
	FROM 부서관리자
	JOIN (SELECT *
		FROM 부서
		WHERE 부서.비고 = 'ACTIVE' OR 부서.비고 = 'aCTIVE' OR 부서.비고 = 'active'
	) as 활동부서
	ON 활동부서.부서번호 = 부서관리자.부서번호

	JOIN 급여
	ON 급여.사원번호 = 부서관리자.사원번호

	JOIN 사원
	ON 사원.사원번호 = 부서관리자.사원번호
	WHERE 급여.종료일자 > now()
	AND 부서관리자.종료일자 > now()

	ORDER BY 급여.연봉 DESC
	LIMIT 5
) as tb

JOIN 직급
ON tb.사원번호 = 직급.사원번호

JOIN 사원출입기록
ON tb.사원번호 = 사원출입기록.사원번호
WHERE 직급.종료일자 > '2021-10-17'
AND 사원출입기록.입출입구분 = 'O'

ORDER BY tb.연봉 DESC;
```

![image](https://user-images.githubusercontent.com/41244373/137633649-068c4af9-d1f8-4fd6-9493-623b23187d40.png)

**2. 인덱스 설정을 추가하여 50 ms 이하로 반환한다.**

1) 인덱스 설정 전 실행 계획
![image](https://user-images.githubusercontent.com/41244373/137634312-b811a28d-0442-43c9-9dc9-8b801795ab8d.png)




2) 인덱스 설정 후 실행 계획

사원출입기록 테이블에서 PRIMARY Key를 '순번' 컬럼 하나로 바꾸고, '사원번호'에 대해 비클러스터링 인덱스를 따로 추가하는 형태로 바꾸었다. 
이를 통해 Full Table Scan 하던 형태를 없애주었다. 

![image](https://user-images.githubusercontent.com/41244373/137635884-ebb9477d-d16e-433a-9edf-59d452adedc0.png)

![image](https://user-images.githubusercontent.com/41244373/137635965-0ca18567-fd4f-4d7d-b2ed-2da567dcce64.png)




<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>


## B. 인덱스 설계


### * 요구사항

- [ ] 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환

    - [ ] [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.

    - [ ] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)

    - [ ] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

    - [ ] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

    - [ ] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)


### * 풀이 과정

**1. [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.**



<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

