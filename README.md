# 🚀 조회 성능 개선하기

### A. 쿼리 연습

1. **쿼리 작성만으로 1s 이하로 반환한다.**

```sql
SELECT 
		상위연봉_부서관리자.사원번호,
    상위연봉_부서관리자.이름,
    상위연봉_부서관리자.연봉,
    상위연봉_부서관리자.직급명,
    사원출입기록.지역,
    사원출입기록.입출입구분,
    사원출입기록.입출입시간    
FROM 
	(SELECT 부서관리자.사원번호, 사원.이름, 급여.연봉, 직급.직급명
		FROM 부서관리자
		INNER JOIN 급여 ON 부서관리자.사원번호 = 급여.사원번호
		INNER JOIN 부서 ON 부서관리자.부서번호 = 부서.부서번호
		INNER JOIN 직급 ON 부서관리자.사원번호 = 직급.사원번호
    INNER JOIN 사원 ON 부서관리자.사원번호 = 사원.사원번호
		WHERE 부서.비고 = 'active'
				AND 부서관리자.종료일자 > NOW()
				AND 급여.종료일자 > NOW()
				AND 직급.종료일자 > NOW()
		ORDER BY 급여.연봉 DESC
		LIMIT 5
	) AS 상위연봉_부서관리자
INNER JOIN 사원출입기록 ON 상위연봉_부서관리자.사원번호 = 사원출입기록.사원번호
WHERE 사원출입기록.입출입구분 = 'O'
ORDER BY 상위연봉_부서관리자.연봉 DESC
```

![explain.png](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8d78815c-e328-49d9-873b-d0eb90e8ea87/explain.png)

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/bbdb5376-9edd-4910-9bbe-1f333d1e89fa/Untitled.png)

**사원출입기록이 full table scan을 해 많은 rows를 조회한 것에 비해 filtered가 1뿐이라 인덱싱 필요**

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/d3901313-bb63-4c7a-996a-9fa5ea22f7af/Untitled.png)

**0.218 ~ 0.235s 소요**

1. **인덱스 설정을 추가하여 50 ms 이하로 반환한다.**

```sql
CREATE INDEX idx_access_log_employee ON tuning.사원출입기록 (사원번호);
```

![explain.png](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b3670242-32fe-4b4a-88c7-6d75e5fe2ea5/explain.png)

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c3ee0c11-32c0-4a1e-86f5-5416fe40ce60/Untitled.png)

**사원출입기록의 type이 ALL에서 ref로 변경됐고 조회한 rows도 4로 줄었다.**

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ef9da990-dfa4-4f61-90ec-93c18c85b74a/Untitled.png)

**0.016~0.000s 소요**

### B. 인덱스 설계

**1) Coding as a Hobby 와 같은 결과를 반환하세요.**

```sql
CREATE INDEX I_hobby ON programmer (hobby);

SELECT 
    hobby,
    ROUND(COUNT(hobby) * 100 / (SELECT COUNT(hobby) FROM programmer),1) AS ratio
FROM programmer
GROUP BY hobby
```

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/096c2657-5880-4577-9554-6bbacf40667d/Untitled.png)

![explain.png](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/5db3f2aa-ea21-4727-bad5-be5d76988934/explain.png)

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/1175f5a2-dab8-4376-af06-fa3e40ce0812/Untitled.png)

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/74422830-157f-4e1b-80b3-61cb489d9130/Untitled.png)

**2) 프로그래머별로 해당하는 병원 이름을 반환하세요. ([covid.id](http://covid.id/), [hospital.name](http://hospital.name/))**

```sql
CREATE INDEX `I_covid_programmer_id` ON `covid` (programmer_id, hospital_id);

SELECT covid.programmer_id, hospital.name
FROM hospital
INNER JOIN covid ON hospital.id = covid.hospital_id;
```

처음 작성한 sql문이다. 이렇게 programmer_id가 covid 테이블에 존재해 programmer는 join하지 않았다.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8720bd8e-0480-4756-859b-aa5fe21b3f80/Untitled.png)

결과에서 programmer_id가 null인 것들이 걸러지지 않아 JOIN을 추가했다.

```sql
SELECT covid.programmer_id, hospital.name
FROM hospital
INNER JOIN covid ON hospital.id = covid.hospital_id
INNER JOIN programmer ON covid.programmer_id = programmer.id;
```

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/971b37b5-8ccf-4c70-a7c1-3437e7579c5a/Untitled.png)

![explain.png](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b4c2a479-90a3-4f5b-9a2b-7df5ac0d70a6/explain.png)

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/ed6580e1-a3a7-4e01-98f5-f8a90d1a4030/Untitled.png)

null 없이 결과가 나오는 것을 확인했다.

**3)프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 [user.id](http://user.id/) 기준으로 정렬하세요. ([covid.id](http://covid.id/), [hospital.name](http://hospital.name/), user.Hobby, user.DevType, user.YearsCoding)**

```sql
CREATE INDEX `I_hospital_id` ON `covid` (hospital_id);
CREATE INDEX `I_hospital_name` ON `hospital` (name);

SELECT c.id, h.name, p.hobby, p.dev_type, p.years_coding
FROM programmer p
INNER JOIN covid c ON c.programmer_id = p.id 
INNER JOIN hospital h ON c.hospital_id = h.id 
WHERE (p.hobby = "yes" and p.years_coding like "0-2%") or p.dev_type like "%student%"
```

![explain.png](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/c3e34cb5-27c4-4d7f-9096-b203b8456455/explain.png)

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/0072b69e-2bbe-4f1b-895c-bdc74d2ba9ac/Untitled.png)

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6c12708a-8b9e-406f-8cd7-627061f794a7/Untitled.png)

**4) 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)**

```sql
SELECT c.stay, count(*)
FROM covid c
INNER JOIN programmer p ON c.programmer_id = p.id 
INNER JOIN member m ON c.member_id = m.id
INNER JOIN hospital h ON c.hospital_id = h.id
WHERE h.name = "서울대병원" AND p.country = "India" AND m.age BETWEEN 20 AND 29
GROUP BY c.stay
```

![explain.png](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/f6f2aec8-b949-4d52-b9b2-0f40ad2c813d/explain.png)

id에 primary key 설정 외에는 인덱스가 없을 때 상황입니다. hospital과 covid가 full table scan 하는 것을 인덱싱을 통해서 성능을 올리면 될 거 같네요!

```sql
CREATE INDEX `I_name` ON `hospital` (name);
CREATE INDEX `I_hospital_id_programmer_id_member_id` ON `covid` (hospital_id, programmer_id, member_id);
```

인덱스를 추가하고 확인해보겠습니다.

![explain.png](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/88c88a41-d009-47ab-98bf-7c041392fe28/explain.png)

non-unique key lookup으로 변경되었습니다! Query cost도 1/10 정도로 줄어들었고요.

where 절에서 `m.age BETWEEN 20 AND 29` 를 사용하고 있어서 age도 인덱싱을 해주니 오히려 성능 저하가 일어나더라고요ㅎㅎ 이미 Priamry로 인덱싱이 걸려 있어 다른 걸 추가할 필요는 없는 거 같습니다!

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/6348a211-69d4-45fe-8c2e-2450ed3a5796/Untitled.png)

**5) 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)**

이 문제는 4번과 거의 동일하게 진행이 됐습니다.

![explain.png](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8b178489-e5c5-4875-b3e6-953f59bb7264/explain.png)

동일한 테이블들이 full table scan을 하고 있었기 때문에 join에서 사용되는 컬럼들을 인덱싱해줬습니다.

![explain.png](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/08fda5bb-8d25-4aa0-b894-d4d60b274142/explain.png)

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/23bd01b5-3741-4cb0-a6d3-46e16100b487/Untitled.png)

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/be6846aa-9dd9-40c3-b1b9-d5e3db88106f/Untitled.png)

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/34aa7868-4ab7-4011-9f57-fd500897d683/Untitled.png)
