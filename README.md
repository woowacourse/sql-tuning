# 🚀 조회 성능 개선하기

## 실습 환경
M1 Mac에서 workbench로 EC2에 띄워져있는 docker mysql에 연결하여 진행하였습니다.

## A. 쿼리 연습
> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)

### 1. 쿼리 작성만으로 1s 이하로 반환한다.

#### 쿼리
```sql
SELECT
    `활동중인 부서의 현재 부서관리자 정보`.사원번호, `활동중인 부서의 현재 부서관리자 정보`.이름, `활동중인 부서의 현재 부서관리자 정보`.연봉, `활동중인 부서의 현재 부서관리자 정보`.직급명, `입출입 정보`.입출입시간, `입출입 정보`.지역, `입출입 정보`.입출입구분
FROM(
    SELECT
        `활동중인 부서의 현재 부서관리자 사원번호`.사원번호, 사원.이름, 급여.연봉, 직급.직급명
    FROM(
        SELECT
            사원번호
        FROM (SELECT 부서번호 FROM 부서 WHERE 비고 = 'active') AS 부서
        JOIN (SELECT 사원번호, 부서번호 FROM 부서관리자 WHERE 종료일자 = '9999-01-01') AS 부서관리자
            ON 부서.부서번호 = 부서관리자.부서번호
    ) AS `활동중인 부서의 현재 부서관리자 사원번호`
    JOIN (SELECT 사원번호, 이름 FROM 사원) AS 사원
        ON `활동중인 부서의 현재 부서관리자 사원번호`.사원번호 = 사원.사원번호
    JOIN (SELECT 사원번호, 직급명 FROM 직급 WHERE 종료일자 = '9999-01-01') AS 직급
        ON `활동중인 부서의 현재 부서관리자 사원번호`.사원번호 = 직급.사원번호
    JOIN (SELECT 사원번호, 연봉 FROM 급여 WHERE 종료일자 = '9999-01-01') AS 급여
         ON `활동중인 부서의 현재 부서관리자 사원번호`.사원번호 = 급여.사원번호
    ORDER BY 연봉 DESC
    LIMIT 0, 5
) AS `활동중인 부서의 현재 부서관리자 정보`
JOIN (SELECT 사원번호, 입출입시간, 지역, 입출입구분 FROM 사원출입기록 WHERE 입출입구분 = 'O') AS `입출입 정보`
    ON `입출입 정보`.사원번호 = `활동중인 부서의 현재 부서관리자 정보`.사원번호
ORDER BY 연봉 DESC;
```

#### 실행결과
<img width="427" alt="스크린샷 2021-10-13 오후 9 22 02" src="https://user-images.githubusercontent.com/45876793/137131312-d7ff977b-d936-432a-a780-d74caddd1c9d.png">


<img width="1091" alt="스크린샷 2021-10-13 오후 9 24 42" src="https://user-images.githubusercontent.com/45876793/137131755-c868e0a4-8ec0-4aba-bc48-8bbdc2d5a7fe.png">

<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

### 2. 인덱스 설정을 추가하여 50 ms 이하로 반환한다.

#### 실행계획 분석

![v1](https://user-images.githubusercontent.com/45876793/137131989-d0e9e238-406c-49bd-b5e1-0eb6bd9539b3.png)

<img width="972" alt="스크린샷 2021-10-13 오후 9 27 02" src="https://user-images.githubusercontent.com/45876793/137132067-f336ac95-07e6-40f7-a89f-ba59bc845ea6.png">

- 많은 rows를 스캔하고 있는 사원출입기록에 인덱스를 걸어주었습니다. 사원번호를 통해 JOIN을 하고 있기 때문에 JOIN 연결 키에 아래와 같이 인덱스를 만들어주었습니다.
```sql
CREATE INDEX `idx_사원출입기록_사원번호` on `tuning`.`사원출입기록` (사원번호);
```

#### 실행결과

![v2](https://user-images.githubusercontent.com/45876793/137132475-d50bfbd4-507e-412e-9270-2d81bc6364e2.png)

<img width="1119" alt="스크린샷 2021-10-13 오후 9 29 48" src="https://user-images.githubusercontent.com/45876793/137132514-f40e1424-d5f4-41eb-8641-a839706b8343.png">

<img width="1090" alt="스크린샷 2021-10-13 오후 9 23 49" src="https://user-images.githubusercontent.com/45876793/137131646-0f51ea11-cf5d-4a62-bb11-476239f4cdb5.png">

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

<div style="line-height:1em"><br style="clear:both" ></div>
<div style="line-height:1em"><br style="clear:both" ></div>

### Coding as a Hobby 와 같은 결과를 반환하세요.

#### 쿼리
#### 인덱스

### 프로그래머별로 해당하는 병원 이름을 반환하세요. (covid.id, hospital.name)
#### 쿼리
#### 인덱스

### 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)
#### 쿼리
#### 인덱스

### 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)
#### 쿼리
#### 인덱스

### 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)
#### 쿼리
#### 인덱스
