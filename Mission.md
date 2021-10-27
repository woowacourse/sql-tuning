## 실습 초기 세팅
> M1 MAC mysql 이슈로, EC2에서 진행

### EC2 초기세팅
```
sudo apt upate
```
- apt 업데이트

### 도커 설치

```
sudo apt-get update && \
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common && \
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - && \
sudo apt-key fingerprint 0EBFCD88 && \
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
sudo apt-get update && \
sudo apt-get install -y docker-ce && \
sudo usermod -aG docker ubuntu && \
sudo curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
sudo chmod +x /usr/local/bin/docker-compose && \
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```

### 실습환경 세팅

```
docker run -d -p 23306:3306 brainbackdoor/data-tuning:0.0.1
```
- 실습환경 이미지를 다운로드 합니다.

```
docker images
```
- 잘 이미지가 설치되었는지 확인 합니다.


```
docker ps -a
```
- 실행중인 이미지들을 확인 합니다.

### 도커 포트포워딩

```
docker stop {컨테이너 이름}
```
- 구동중인 도커의 포트번호를 바꾸는 방법도 있지만, 귀찮으니 구동중인 도커를 종료합니다.

```
docker run -d -p {호스트 포트번호}:{컨테이너 포트 번호}/{프로토콜} {이미지 이름}
```

- 우리는 디비에 접근할것이니 8080을 통해 외부에서 접속하면 3306 포트로 들어가게 합니다.
- 프로토콜은 디폴트로 TCP로 잡히니 비워둡니다.

```
sudo docker run -d -p 8080:3306 brainbackdoor/data-tuning:0.0.1
```

- https://tttsss77.tistory.com/155


---

<br>

# A 쿼리연습

## 요구사항
> 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.  

(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)
급여 테이블의 사용여부 필드는 사용하지 않습니다. 현재 근무중인지 여부는 종료일자 필드로 판단해주세요.

## Step1
- [x] 쿼리 작성만으로 1s 이하로 반환한다.

### 쿼리 설계
- [한글깨짐을 해결하고](https://yollo.tistory.com/43), [ERD를 확인](https://dololak.tistory.com/457)합니다.

![image](https://user-images.githubusercontent.com/43930419/138581819-fc7fccd3-37ac-46d6-bf76-c6961d86019f.png)

- 부서관리자 테이블의 
  - 사원번호를 통해
    - 사원 테이블 -> 이름
    - 급여 테이블 -> 연봉
    - 직급 테이블 -> 직급명
  - 부서번호를 통해 
    - 부서테이블 -> 부서번호

와 같이 JOIN 시키면 원하는 정보를 얻어올 수 있을것으로 파악되었습니다.

---

### 쿼리, 결과

```sql
SELECT 상위연봉_부서관리자.사원번호, 상위연봉_부서관리자.이름, 상위연봉_부서관리자.연봉, 상위연봉_부서관리자.직급명, 
사원출입기록.입출입시간, 사원출입기록.지역, 사원출입기록.입출입구분
FROM (
	SELECT 부서관리자.사원번호, 사원.이름, 급여.연봉, 직급.직급명
	FROM 부서관리자
		JOIN 사원 ON 부서관리자.사원번호 = 사원.사원번호
        JOIN 급여 ON 부서관리자.사원번호 = 급여.사원번호
        JOIN 직급 ON 부서관리자.사원번호 = 직급.사원번호
        JOIN 부서 ON 부서관리자.부서번호 = 부서.부서번호
		WHERE 부서.비고 = 'active' AND 부서관리자.종료일자 > NOW() AND 급여.종료일자 > NOW() AND 직급.종료일자 > NOW()
        ORDER BY 급여.연봉 DESC LIMIT 5
) AS 상위연봉_부서관리자 
JOIN 사원출입기록 ON 상위연봉_부서관리자.사원번호 = 사원출입기록.사원번호
WHERE 사원출입기록.입출입구분 = 'O'
ORDER BY 상위연봉_부서관리자.연봉 DESC, 사원출입기록.지역;
```


> 결과

![image](https://user-images.githubusercontent.com/43930419/138583906-d124e21e-c8a7-4b65-beb3-c30a2971ec1f.png)

![image](https://user-images.githubusercontent.com/43930419/138583924-b27c5516-9847-4436-9888-4f0c8c21d76f.png)



---

## Step2
- [x] 인덱스 설정을 추가하여 50 ms 이하로 반환한다.

### 실행계획 파악

![a](https://user-images.githubusercontent.com/43930419/138583974-f52fc4b9-8321-4711-8b0b-0a50a2f816ad.png)

- 현재 Full Table 스캔이 일어나는 `사원출입기록.사원번호` 를 인덱스를 걸어보기로 했습니다.


### 인덱스 설정, 결과

```sql
CREATE INDEX index_사원번호 ON 사원출입기록 (사원번호)
```

![b](https://user-images.githubusercontent.com/43930419/138584167-13910565-58d9-4952-88d7-fba305e3d741.png)

![image](https://user-images.githubusercontent.com/43930419/138584183-a7f9211b-2595-4bc8-ac10-408922f3078b.png)

> `0.3 ~ 0.4` -> `0.007 ~ 0.008` 로 줄어든것을 확인할 수 있습니다.


---

<br>

# B 인덱스 설계

## 요구사항 

> 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환

![image](https://user-images.githubusercontent.com/43930419/138585574-0e2ab087-827e-4c62-8634-1655bdfc6dd1.png)


## Step1
- [x] [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.

### 요구사항 분석, 쿼리작성

![image](https://user-images.githubusercontent.com/43930419/138584460-fc31bcec-6402-4164-bd28-1bc750cc71b2.png)

```sql
SELECT hobby, (COUNT(hobby) / (SELECT COUNT(hobby) FROM programmer) * 100) AS percent
FROM programmer
GROUP BY hobby;
```

![image](https://user-images.githubusercontent.com/43930419/138584970-48201fb9-827a-4f66-bf4d-6d1e991d86dc.png)

![c](https://user-images.githubusercontent.com/43930419/138584997-6a71a9ed-6dd5-4319-a6b4-cd0f6c7a4ed9.png)


### 개선
> programmer의 hobby에 index를 겁니다.

![image](https://user-images.githubusercontent.com/43930419/138585253-977b3253-f595-4b5d-8997-19112c8f0bc9.png)

![image](https://user-images.githubusercontent.com/43930419/138585328-e6c68969-e50f-4ecd-9e6e-54033e9d1360.png)



<br>


---

## Step2
- [x] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)

### 요구사항 분석, 쿼리작성
> 프로그래머별로 확인해야하니, covid.id가 아닌 covid.programmer_id 를 select 하도록 수정

```sql
SELECT covid.programmer_id, hospital.name
FROM covid
JOIN hospital ON covid.hospital_id = hospital.id
AND covid.programmer_id IS NOT NULL 
```

![image](https://user-images.githubusercontent.com/43930419/138586528-b2d1a7ef-fc0a-41a8-b75e-0c5c2001f1f4.png)

![image](https://user-images.githubusercontent.com/43930419/138586520-15f1be24-c5e7-4efe-b26b-fb422910e8b1.png)




### 개선
> hospial에 pk를 걸어주었습니다.

![image](https://user-images.githubusercontent.com/43930419/138586547-6d75c29a-28cb-4dee-a0df-d29b27ab760f.png)

![image](https://user-images.githubusercontent.com/43930419/138586617-00578af0-e469-448c-ada1-713565591e74.png)


- 큰차이가 보이진 않네요..

<br>

---

## Step3
- [x] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)


### 요구사항 분석, 쿼리작성
> user테이블이 없어 user.id가 아닌 programmer.id로 정렬했습니다.

- 취미인 학생:  `programmer.dev_type = 'Student' AND programmer.hobby = 'Yes'`
- 주니어: `programmer.years_coding = '0-2 years'`

```sql
SELECT covid.id, hospital.name, programmer.hobby, programmer.dev_type, programmer.years_coding
FROM covid
    JOIN programmer ON covid.programmer_id = programmer.id
    JOIN hospital ON covid.hospital_id = hospital.id
WHERE (programmer.dev_type = 'Student' AND programmer.hobby = 'Yes') OR programmer.years_coding = '0-2 years'
ORDER BY programmer.id;
```

![b-3](https://user-images.githubusercontent.com/43930419/138587694-3bc317ca-f0ee-4ebf-a2e8-6b47d2f798f3.png)

- 30초 오버하면서 쿼리도 안돌아감


### 개선
> JOIN시 연결하는 Key들은 양쪽다 INDEX를 가지게 하라.

```
// pk 추가
hospital.id

// index 추가
programmer.id
covid.programmer_id
covid.hospital_id
```

- programmer 의 id에 pk가 예상치 못한 에러가 발생한다면서 안걸리더라구요..  
  - 이유는 모르겠네요 -_-... 그래서 일단 인덱스만 넣어주었습니다.

```sql
SELECT covid.id, hospital.name, programmer.hobby, programmer.dev_type, programmer.years_coding
FROM covid
    JOIN programmer ON covid.programmer_id = programmer.id
    JOIN hospital ON covid.hospital_id = hospital.id
WHERE programmer.hobby = 'Yes' AND (programmer.dev_type like '%Student%' OR programmer.years_coding = '0-2 years')
```

- 기존 `프로그래밍이 취미인 학생 / 혹은 주니어(0-2)` 이었던것을
- `프로그래밍이 취미인 / 학생 혹은 주니어(0-2년) 으로 해석` 으로 재해석하면서 쿼리를 변경했습니다.
- `'Back-end developer;Designer;DevOps specialist;Front-end developer;Full-stack developer;Product manager;QA or test developer;Student'`
  - 위와같이 Student가 뒤에 끼어있는경우도 확인하고, 쿼리를 변경했습니다.
- id에 index를 걸었음으로, order by 정렬 연산을 제거했습니다.

<br>

![image](https://user-images.githubusercontent.com/43930419/138588568-c07a1225-67d1-4d4e-8e03-a7e273e38b40.png)

![image](https://user-images.githubusercontent.com/43930419/138588576-720b3d37-58b4-41c0-9800-e44a2991e9f4.png)

---

## Step4
- [x] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)


### 요구사항 분석, 쿼리작성
> 국적(country =s India) 정보는 programmer에서밖에 못 얻지 못하므로 programmer를 join할 필요가 있었습니다.  

```sql
SELECT covid.stay, count(*) as count
FROM covid
    JOIN programmer ON covid.programmer_id = programmer.id
    JOIN hospital ON covid.hospital_id = hospital.id 
    JOIN member ON programmer.member_id = member.id
WHERE hospital.name = '서울대병원' AND programmer.country = 'India' AND member.age BETWEEN 20 AND 29
GROUP BY covid.stay
```

![image](https://user-images.githubusercontent.com/43930419/138592413-2008aac9-f2b2-4577-b12c-0a3e671f330d.png)
![image](https://user-images.githubusercontent.com/43930419/138592421-5fa570d8-de90-4e8e-bb94-d09ebf87515d.png)


### 개선

```
// INDEX 추가
hospital.name이 text 였던것을 VARCHAR로 변경 후 인덱스 추가
JOIN에 걸리는 programmer.member_id 인덱스 추가
```

![image](https://user-images.githubusercontent.com/43930419/138592695-5d48150f-9d58-43fc-9a80-231f1f5e5f8f.png)
![image](https://user-images.githubusercontent.com/43930419/138592703-f732d28e-89fa-4300-808d-90b2038c7af8.png)


<br>

---

## Step5
- [x] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)


### 요구사항 분석, 쿼리작성
> user테이블이 없어 programmer로 진행했습니다.

```sql
SELECT programmer.exercise, count(*) as count
FROM hospital
    JOIN covid ON hospital.id = covid.hospital_id
    JOIN programmer ON covid.programmer_id = programmer.id
    JOIN member ON programmer.member_id = member.id
WHERE hospital.name = '서울대병원' AND member.age BETWEEN 30 AND 39
GROUP BY programmer.exercise
```

![image](https://user-images.githubusercontent.com/43930419/138595158-e2682717-b9d1-42fc-8eb9-0fdb6e1423ca.png)
![image](https://user-images.githubusercontent.com/43930419/138595171-782c7324-d823-4dc9-abc9-5a8b6f5469ac.png)

### 개선
> hospital에 unique 속성추가

![image](https://user-images.githubusercontent.com/43930419/138595216-1a85760a-81ad-42bc-9a5e-f6273d6e274d.png)
![image](https://user-images.githubusercontent.com/43930419/138595225-e482cf28-dcbd-4f6f-8525-a1bfd2e127e1.png)

- 드라마틱한 차이는 없으나, 어느정도의 성능 개선이 이루어진것을 확인할 수 있었습니다.


---

## Reference
- https://engineering.linecorp.com/ko/blog/mysql-workbench-visual-explain-index/
- https://velog.io/@gillog/SQL-Index%EC%9D%B8%EB%8D%B1%EC%8A%A4
- https://sheerheart.tistory.com/entry/MySQL-%ED%95%98%EA%B8%B0-%EC%89%AC%EC%9A%B4-%EC%8B%A4%EC%88%98%EC%99%80-Tip%EC%97%90-%EB%8C%80%ED%95%9C-%EC%86%8C%EA%B0%9C
- https://jojoldu.tistory.com/243
- https://hoing.io/archives/5960
- https://opentutorials.org/course/1555/8760