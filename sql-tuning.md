
# A
> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
> 
> (사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)
>
> 급여 테이블의 사용여부 필드는 사용하지 않습니다. 현재 근무중인지 여부는 종료일자 필드로 판단해주세요.

### 1 쿼리 작성만으로 1s 이하로 반환한다.


```sql
SELECT 잘나가는_부서관리자.사원번호, 이름, 연봉, 직급명, 입출입시간, 지역, 입출입구분
FROM (SELECT 부서관리자.사원번호, 사원.이름, 급여.연봉, 직급.직급명
      FROM 부서, 부서관리자, 사원, 직급, 급여
      WHERE 부서관리자.부서번호 = 부서.부서번호 AND 부서관리자.사원번호 = 사원.사원번호 AND 부서관리자.사원번호 = 직급.사원번호 AND 부서관리자.사원번호 = 급여.사원번호
        AND 부서관리자.종료일자 > now() AND 직급.종료일자 > now() AND 급여.종료일자 > now() AND lower(부서.비고) like '%active%'
      ORDER BY 연봉 DESC LIMIT 5) 잘나가는_부서관리자, 사원출입기록
WHERE 잘나가는_부서관리자.사원번호 = 사원출입기록.사원번호 AND 사원출입기록.입출입구분 = 'O'
ORDER BY 연봉 DESC, 지역;
```

- Duration/Fetch Time: 0.250 sec / 0.000010 sec

### 2 인덱스 설정을 추가하여 50ms 이하로 반환한다.

```sql
CREATE INDEX `idx_사원출입기록_사원번호` ON `tuning`.`사원출입기록` (사원번호);
```

- Duration/Fetch Time: 0.0024 sec / 0.000012 sec

# B

### [Coding as a Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.
```sql
SELECT hobby, (COUNT(hobby) / (SELECT COUNT(*) AS total_count FROM programmer)) * 100 AS percent
FROM programmer
GROUP BY hobby;
```

- Duration/Fetch Time: 1.355 sec / 0.0000069 sec

#### index 추가
```sql
CREATE INDEX `idx_programmer_hobby` ON `programmer` (hobby);
```

- Duration/Fetch Time: 0.063 sec / 0.0000069 sec

### 프로그래머별로 해당하는 병원 이름을 반환하세요. 
- (covid.id, hospital.name)

```sql
SELECT covid.programmer_id, hospital.name
FROM hospital
    LEFT JOIN covid ON hospital.id = covid.hospital_id;
```
- Duration/Fetch Time: 0.448 sec / 0.242 sec

```sql
alter table hospital add primary key (id);
alter table programmer add primary key (id);

CREATE INDEX `idx_covid_hospital_id` ON `covid` (hospital_id);
CREATE INDEX `idx_covid_programmer_id` ON `covid` (programmer_id);
```

- Duration/Fetch Time: 0.0041 sec / 0.0018 sec

### 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. 
- (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)

```sql
SELECT covid.id, hospital.name
FROM covid
    JOIN hospital ON covid.hospital_id = hospital.id
    JOIN programmer ON covid.programmer_id = programmer.id
WHERE hobby = 'Yes' AND (dev_type like '%Student%' OR years_coding = '0-2 years');
```

- Duration/Fetch Time: 0.017 sec / 0.0077 sec
- 인덱스 설정은 이전에 추가한 인덱스 이외에 변경사항 없음

### 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)
```sql
SELECT covid.stay, count(covid.id) count
FROM hospital
    JOIN covid ON covid.hospital_id = hospital.id
    JOIN programmer ON covid.programmer_id = programmer.id
    JOIN member ON covid.member_id = member.id
WHERE hospital.name = '서울대병원' AND programmer.country = 'India' AND member.age BETWEEN 20 AND 29
GROUP BY covid.stay;
```

- Duration/Fetch Time: 0.314 sec / 0.0000072 sec

```sql
CREATE INDEX `idx_covid_stay` ON `covid` (stay);
```

- Duration/Fetch Time: 0.083 sec / 0.0000079 sec

### 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)
```sql
SELECT programmer.exercise, count(covid.id) count
FROM covid
JOIN hospital ON hospital.id = covid.hospital_id 
JOIN programmer ON covid.programmer_id = programmer.id 
JOIN member ON covid.member_id = member.id
WHERE hospital.name = '서울대병원' AND member.age BETWEEN 30 AND 39
GROUP BY programmer.exercise;
```

- Duration/Fetch Time: 0.107 sec / 0.0000079 sec

```sql
SELECT STRAIGHT_JOIN p.exercise, count(covid.id) count
FROM hospital
JOIN covid ON hospital.id = covid.hospital_id 
JOIN member ON covid.member_id = member.id
JOIN (SELECT id, exercise FROM programmer ORDER BY exercise) p ON covid.programmer_id = p.id
WHERE hospital.name = '서울대병원' AND member.age BETWEEN 30 AND 39
GROUP BY p.exercise;
```

- Duration/Fetch Time: 0.037 sec / 0.0000079 sec

