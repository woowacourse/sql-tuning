# 🚀 조회 성능 개선하기

## A. 쿼리 연습

### * 요구사항

<div style="line-height:1em"><br style="clear:both" ></div>

> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)


<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

### * 쿼리

```sql
SELECT a.사원번호, a.이름, a.연봉, a.직급명, MAX(r.입출입시간) 입출입시간, r.지역, r.입출입구분
FROM (
       SELECT m.사원번호, e.이름, s.연봉, j.직급명
       FROM 부서관리자 m
       JOIN 부서 d ON m.부서번호 = d.부서번호
       JOIN 급여 s ON m.사원번호 = s.사원번호
       JOIN 사원 e ON m.사원번호 = e.사원번호
       JOIN 직급 j ON m.사원번호 = j.사원번호
       WHERE m.종료일자 >= now() AND d.비고 = 'active'
         AND m.종료일자 = s.종료일자 AND m.종료일자 = j.종료일자
       ORDER BY s.연봉 DESC
         LIMIT 5) a
JOIN 사원출입기록 r ON a.사원번호 = r.사원번호
WHERE 입출입구분 = 'O'
group by 사원번호, 연봉, 직급명, 지역
order by 연봉 DESC;
```
1. 쿼리 작성만으로 1s 이하로 반환한다.
   

![image](https://user-images.githubusercontent.com/62014888/137580102-ba1051b3-3b41-4708-b173-86ff11cfd62f.png)

![explain](https://user-images.githubusercontent.com/62014888/137674244-7396d751-a040-4f72-b7c0-96b869fd749f.png)



- 1s 이하로 반환되는데 왜이렇게 duration이 들쑥날쑥인지 모르겠네요..ㅋㅋㅋㅠㅠ

2. 인덱스 설정을 추가하여 50 ms 이하로 반환한다.


![image](https://user-images.githubusercontent.com/62014888/137580160-19a39e6e-6e27-4928-8758-234770648e9e.png)

- 조인 key인 사원테이블의 사원번호에는 인덱스가 걸어져있었고 사원입출입기록 테이블의 사원번호에는 인덱스가 걸어져있지 않아 join buffer가 발생했습니다.
- 그래서 사원입출입기록 테이블의 사원번호에 인덱스를 걸어서 50 ms 이하로 반환하도록 만들었습니다.

```sql
CREATE INDEX 'idx_사원출입기록_사원번호'  ON 'tuning'.'사원출입기록' (사원번호);
```


![image](https://user-images.githubusercontent.com/62014888/137580368-2af4b880-1fc3-431b-a14e-964ebfa4d702.png)

![image](https://user-images.githubusercontent.com/62014888/137580390-3573dc4e-0afb-449a-9c96-da450ae955d5.png)

![explain1](https://user-images.githubusercontent.com/62014888/137674388-6deff77c-c342-40a7-97e4-a229e9da7df8.png)


## B. 인덱스 설계

### * 요구사항

- [x] 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환

- [x] [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.
        
```sql
SELECT 
ROUND((SELECT count(*) FROM programmer WHERE hobby = 'Yes') / count(*) * 100, 1) yes,
ROUND((SELECT count(*) FROM programmer WHERE hobby = 'No') / count(*) * 100, 1) no
FROM programmer;

```

- 결과

![image](https://user-images.githubusercontent.com/62014888/137585378-c539d69c-cf43-4ce1-b737-2beef890b194.png)


- 인덱스를 추가로 걸지 않았을 때

![image](https://user-images.githubusercontent.com/62014888/137675930-a153033a-4ee4-4d32-907d-1e44394b193e.png)

![image](https://user-images.githubusercontent.com/62014888/137676049-b1a7fe1f-daf4-4b68-b36b-571249fda22c.png)

- 우선 programmer id를 pk로 만들어 인덱스를 추가해 Full Table Scan을 Full Index Scan으로 만들었고  
hobby에 인덱스를 추가해서 인덱스로 조회하도록 수정했습니다.
  
- 재밌는건 id를 pk로 만들어서 인덱스를 만들어줬는데 rows 값이 달라졌다는거.  
일단 공식문서에서는 rows는 추정 값이라고 하네요. 여태 테이블 row 수 인줄 알고 있었는데..  
  pk를 추가했을 뿐인데 rows가 달라지는 이유는 정확히는 모르겠습니당.. pk가 추가됨에 따라 탐색하는 수가 달라지기에 그런건가..?

![image](https://user-images.githubusercontent.com/62014888/137677928-be1108d7-cd21-4267-9627-222ca6937b7f.png)


```sql
ALTER TABLE 'subway'.'programmer' 
CHANGE COLUMN 'id' 'id' BIGINT(20) NOT NULL ,
ADD PRIMARY KEY ('id');

CREATE INDEX 'idx_programmer_hobby'  ON 'subway'.'programmer' (hobby);
```

![image](https://user-images.githubusercontent.com/62014888/137585387-93f3bdc3-cdd8-4d49-b2e0-619783efb12e.png)

![image](https://user-images.githubusercontent.com/62014888/137676770-69cf1153-4943-4469-938b-f8f29924e413.png)


- [x] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)

```sql
SELECT c.id, h.name FROM hospital h 
INNER JOIN covid c ON c.hospital_id = h.id
INNER JOIN programmer p ON p.id = c.programmer_id;
```
  
- 결과


![image](https://user-images.githubusercontent.com/62014888/137679030-091a84e0-21e3-481e-bb37-0f74f44cc49b.png)

- 인덱스를 추가로 걸지 않았을 때

![image](https://user-images.githubusercontent.com/62014888/137679182-c183be1d-aae1-47bb-99c0-e4437bef7cd1.png)

![image](https://user-images.githubusercontent.com/62014888/137679422-2efcd005-01a5-464b-b52c-7fe95f8145ba.png)

- join buffer가 발생하여 hospital의 id는 pk로 covid의 hospital_id, programmer_id에 인덱스를 걸어주었습니다.

```sql
ALTER TABLE 'subway'.'hospital' 
CHANGE COLUMN 'id' 'id' INT(11) NOT NULL ,
ADD PRIMARY KEY ('id');

CREATE INDEX 'idx_covid_programmer_id' ON 'subway'.'covid' (programmer_id);
CREATE INDEX 'idx_covid_hospital_id' ON 'subway'.'covid' (hospital_id);
```

![image](https://user-images.githubusercontent.com/62014888/137680829-4f529b5b-1fcf-45a1-a99a-3b7aea1583da.png)

![image](https://user-images.githubusercontent.com/62014888/137680893-5b3fa558-c2c6-4489-9660-6b150defa680.png)


- [x] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)


```sql
SELECT c.id, c.member_id, h.name, p.hobby, p.dev_type, p.years_coding FROM hospital h
JOIN covid c
ON h.id = c.hospital_id
JOIN programmer p
ON c.member_id = p.member_id
WHERE p.hobby = 'Yes'
AND (p.student != 'No' OR p.years_coding = '0-2 years');
```

- 결과

![image](https://user-images.githubusercontent.com/62014888/137683233-3ce65038-abdf-49c8-980c-50b1f7778406.png)

- 인덱스를 추가로 걸지 않았을 때

![image](https://user-images.githubusercontent.com/62014888/137682794-e999dcab-8bb9-45d7-86c5-5036bcd336a9.png)


- join buffer를 해결하기 위해 covid, programmer의 member_id에 인덱스를 걸었다.

```sql
CREATE INDEX 'idx_covid_member_id' ON 'subway'.'covid' (member_id);
CREATE INDEX 'idx_programmer_member_id' ON 'subway'.'programmer' (member_id);
```

![image](https://user-images.githubusercontent.com/62014888/139208003-f5569cfd-ecc2-432f-991b-03ad986af427.png)

![image](https://user-images.githubusercontent.com/62014888/139208165-78ccb2e1-9e7a-4683-bf55-b9e7c901c8a2.png)


- [x] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)

```sql
SELECT c.stay, count(c.id) FROM programmer p 
INNER JOIN (SELECT id FROM member WHERE age BETWEEN 20 AND 29) m
ON p.member_id = m.id
INNER JOIN covid c
ON c.member_id = m.id
INNER JOIN (SELECT id FROM hospital WHERE name = '서울대병원') h
ON c.hospital_id = h.id
WHERE p.country = 'India'
GROUP BY stay  
ORDER BY null;
```

- 결과

![image](https://user-images.githubusercontent.com/62014888/137683594-332882b3-542a-4dd6-b9aa-f2847b9f7f03.png)

- 인덱스를 추가로 걸지 않았을 때

![image](https://user-images.githubusercontent.com/62014888/137683656-3e516246-5bfb-4b2a-8a55-c963fe17521d.png)

![image](https://user-images.githubusercontent.com/62014888/137683768-0b2fa2c2-cecc-4a4d-a256-03ae44eac7ca.png)

- hospital의 name은 중복이 없는 데이터이므로 unique로 변경해서 인덱스를 추가해주었고 age에도 인덱스를 추가해주었다.  
country에도 인덱스를 걸어주었다.
  
```sql
ALTER TABLE 'subway'.'hospital'
CHANGE COLUMN 'name' 'name' VARCHAR(255) NULL ,
ADD UNIQUE INDEX 'name_UNIQUE' ('name' ASC);

CREATE INDEX 'idx_programmer_country' ON 'subway'.'programmer' (country);
CREATE INDEX 'idx_member_age' ON 'subway'.'member' (age);
```

![image](https://user-images.githubusercontent.com/62014888/137685397-94acb036-a5c0-4e58-a195-75cb0ef9b9f4.png)

![image](https://user-images.githubusercontent.com/62014888/137685039-2876d6c2-ad10-4464-aece-df75b7d24c06.png)


- [x] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)

```sql
SELECT exercise, count(c.id) FROM 
(SELECT p.member_id, p.exercise FROM (SELECT id FROM member WHERE age BETWEEN 30 AND 39) m
JOIN programmer p ON p.member_id = m.id) t
JOIN covid c
ON t.member_id = c.member_id
JOIN (SELECT id FROM hospital h WHERE name = '서울대병원') h
ON c.hospital_id = h.id
GROUP BY exercise
ORDER BY null;
```

- 결과

- 앞서 걸었던 인덱스들(age, name, pk로 바꾼 id, member_id, hospital_id)에 의해서 요구사항을 만족시켜서 조회되는 모습을 볼 수 있습니다.

![image](https://user-images.githubusercontent.com/62014888/137686002-4c2c0b16-e1e3-49ba-9139-1b524e06ae22.png)

![image](https://user-images.githubusercontent.com/62014888/137686057-cc93883a-b714-4cc1-8a9a-9d63d2c7d7ad.png)

![image](https://user-images.githubusercontent.com/62014888/137685884-ce30bf5c-240c-4dd2-9457-cd2f8e74740b.png)

<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

## C. 프로젝트 요구사항

### a. 페이징 쿼리를 적용 

### b. Replication 적용 
