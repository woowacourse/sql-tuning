# 🚀 조회 성능 개선하기

## A. 쿼리 연습

### 실습환경 세팅

```sh
$ docker run -d -p 23306:3306 brainbackdoor/data-tuning:0.0.1
```

- [workbench](https://www.mysql.com/products/workbench/)에서 localhost:23306 (ID: user, PW: password)로 접속한다.

### 요구사항

> 활동 중인(Active) 부서의 현재 부서 관리자 중 연봉 상위 5위 안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회한다.
> - 사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간
> - 급여 테이블의 사용여부 필드는 사용하지 X
> - 현재 근무 중인지 여부는 종료일자 필드로 판단한다.

<br/>

- [x] 쿼리 작성만으로 1s 이하로 반환한다.

<details>
  <summary>쿼리 작성</summary>
  <br/>

  ```sql
  select 
      사원.사원번호, 
      사원.이름, 
      급여.연봉,
      직급.직급명
  from 
      사원
  join 
      급여 on 사원.사원번호 = 급여.사원번호
  join 
      부서관리자 on 사원.사원번호 = 부서관리자.사원번호
  join
      직급 on 사원.사원번호 = 직급.사원번호
  join 
      부서 on 부서관리자.부서번호 = 부서.부서번호
  where 
      급여.종료일자 = '9999-01-01' and 
      부서관리자.종료일자 = '9999-01-01' and 
      직급.직급명 = 'Manager' and
      부서.비고 = 'active'
  order by 
      급여.연봉 desc
  limit 5;
  
  select 
      사원_top5.사원번호, 
      사원_top5.이름, 
      사원_top5.연봉, 
      사원_top5.직급명, 
      사원출입기록.입출입시간, 
      사원출입기록.지역, 
      사원출입기록.입출입구분
  from 
      사원출입기록
  join (
      select 
          사원.사원번호, 
          사원.이름, 
          급여.연봉,
          직급.직급명
      from 
          사원
      join 
          급여 on 사원.사원번호 = 급여.사원번호
      join 
          부서관리자 on 사원.사원번호 = 부서관리자.사원번호
      join
          직급 on 사원.사원번호 = 직급.사원번호
      join 
          부서 on 부서관리자.부서번호 = 부서.부서번호
      where 
          급여.종료일자 = '9999-01-01' and 
          부서관리자.종료일자 = '9999-01-01' and 
          직급.직급명 = 'Manager' and
          부서.비고 = 'active'
      order by 
          급여.연봉 desc
      limit 5
  ) as 사원_top5 on 사원출입기록.사원번호 = 사원_top5.사원번호
  where 
      사원출입기록.입출입구분 = 'O'
  order by 
      사원_top5.연봉 desc,
      사원출입기록.입출입시간 desc;
  ```

</details>

<details>
  <summary>실행 결과</summary>
  
  #### 소요 시간
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137327316-03bd818c-65cb-478a-abf5-7da0ca112cf9.png">
  </p>

  #### 테이블 출력
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137328626-5a7d8bfa-2b97-4979-a636-ab3d0741561f.png">
  </p>

  #### 실행 계획
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137470893-7f02025f-97b2-462e-b504-97697e61e3e5.png">
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137478973-b4ca7918-8072-4f84-a5f6-122b309c9efe.png">
  </p>

</details>

<details>
  <summary>질문</summary>

  #### 1.
  문제에서 "~ `최근에` 각 지역별로 언제 퇴실했는지 조회한다."라고 돼있는데요.<br/>
  이 뜻은 입출입시간을 기준으로 내림차순 정렬하라는 걸까요?<br/>
  현재는 이렇게 작성되어 있는데, 검프의 생각이 궁금합니다!<br/>

  #### 2.
  강의 자료의 정답과 비교하면, 테이블의 입출입시간이 맞지 않는데요.<br/>
  혹시 쿼리가 틀린 건가 고민하다 정답의 값이 있긴 한 건지 먼저 확인해야겠다 싶어 `사원번호 110039`를 기준으로 조회해봤습니다.<br/>
  
  ```sql
  select *
  from 사원출입기록
  where 사원번호 = 110039;
  ```
  <br/>
  
  테이블은 아래처럼 출력됐어요.<br/>
  정답에 있는 입출입시간 값(e.g. 2020-09-06)이 아예 없었습니다.<br/>
  저만 그런가 싶어 몇몇 크루들한테 물어봤는데, 저와 같은 경우도 있고 아닌 경우도 있더라구요 😵‍💫<br/>
  검프는 결과가 똑같이 나오나요??<br/>

  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137324185-7e567174-9ac5-474c-81b4-cc30af339fda.png">
  </p>

</details>

<br/>
    
- [x] 인덱스 설정을 추가하여 50ms 이하로 반환한다.

<details>
  <summary>쿼리 작성</summary>
  <br/>

  ```sql
  create index `idx_사원번호` on 사원출입기록 (사원번호);
  ```

</details>

<details>
  <summary>실행 결과</summary>

  #### 소요 시간
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137478470-80ab4752-3c1a-453a-9857-f8675409350c.png">
  </p>

  #### 실행 계획
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137478764-52e8b000-e8c3-490a-ad5f-07448b087bb4.png">
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137478881-ddc20dec-d35d-42ef-b2b3-cbd71ca6abba.png">
  </p>

</details>

<details>
  <summary>질문</summary>
  <br/>

  기존에는 `사원출입기록`에 아래처럼 인덱스가 걸려 있어, 조인을 할 때 Full Table Scan이 발생했습니다.<br/>

  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137479229-248f8549-9c51-475a-9c30-b31a74857efa.png">  
  </p>
  <br/>

  그래서 Full Table Scan을 해결하려 (사원번호)로 인덱스를 걸었는데요.<br/>
  그리고 실행 시간을 확인하니 67-70ms 정도는 나오는데, 50ms 이하로는 안 나오더라구요 🥲<br/>
  다른 곳도 개선할 수 있는 부분이 있을까 싶어 여기저기 찾아보고 인덱스를 걸어봤는데요.<br/>
  오히려 실행 시간이 늘어나는 경우도 있고, 딱히 나아지지 않았습니다 😂<br/>
  검프는 어디에 인덱스를 추가해줬나요? 혹시 제가 놓친 게 있을까요??<br/>

</details>

<br/>

## B. 인덱스 설계

### 실습환경 세팅

```sh
$ docker run -d -p 13306:3306 brainbackdoor/data-subway:0.0.2
```

- [workbench](https://www.mysql.com/products/workbench/)에서 localhost:13306 (ID: root, PW: masterpw)로 접속한다.

### 요구사항

> 주어진 데이터셋을 활용하여 조회 결과를 100ms 이하로 반환한다.

<br/>

- [x] [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환한다.

<details>
  <summary>쿼리 작성</summary>
  <br/>

  ```sql
  select
    hobby,
    round((count(member_id) / (select count(member_id) from programmer where member_id is not null)) * 100, 1) as 'percentage'
  from
    programmer
  where
    member_id is not null
  group by
    hobby
  order by
    null;
  ```

</details>

<details>
  <summary>실행 결과</summary>
  
  #### 소요 시간
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137529337-42f6b5d1-1c74-4b94-a123-38161f28bcda.png">
  </p>

  #### 테이블 출력
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137529718-b2a57cd5-ceab-4062-8e22-d2e8251bae3c.png">  
  </p>

  #### 실행 계획
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137529544-39ce68bc-e50f-44c6-be8d-bb91826e6947.png">
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137529464-2ee49e78-75a8-4577-829b-58b6087139cd.png">
  </p>

</details>

<details>
  <summary>정리</summary>

  #### 1.
  먼저, `programmer`에 어떤 인덱스가 있는지 확인했다. 처음에는 아무 인덱스도 없었다.

  ```sql
  show index from programmer;
  ```
  <br/>
  
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137531335-94b8cbdb-de70-47b6-9401-e89684082a4f.png">  
  </p>

  #### 2.
  인덱스를 추가하여 성능 개선을 하기 앞서, 기대하는 결과가 나오는 쿼리를 먼저 작성했다.
  
  ```sql
  select
    hobby,
    round((count(member_id) / (select count(member_id) from programmer)) * 100, 1) as 'percentage'
  from
    programmer
  group by
    hobby
  order by
    null;
  ```
  <br/>
  
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137531449-d27172e0-e04b-49b0-8687-bbb9986c78c6.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137531515-04c1a93d-765d-45b2-911b-5202c693a20c.png">  
  </p>

  #### 3.
  다음으로, 인덱스를 추가했다.<br/>
  커버링 인덱스를 사용해서 성능을 개선시키고 싶었다.<br/>
  인덱스를 어떻게 설계해야 할까 고민하다, `member_id`가 `null`인 레코드가 몇 개 있는 것을 발견했다.<br/>
  이와 `hobby` 컬럼을 묶어 인덱스를 추가하면, `where`와 `group by`를 적절하게 활용해서 커버링 인덱스로 쓸 수 있을 거라 생각했다.<br/>

  ```sql
  create index `idx_member_id_hobby` on programmer (member_id, hobby);

  select
    hobby,
    round((count(member_id) / (select count(member_id) from programmer where member_id is not null)) * 100, 1) as 'percentage'
  from
    programmer
  where
    member_id is not null
  group by
    hobby
  order by
    null;
  ```

  #### 4.
  예상대로 커버링 인덱스로 활용됐다.<br/>
  인덱스가 없을 때보다는 성능이 많이 개선됐다. 그러나, 요구사항인 100ms 이하의 쿼리는 아니었다.<br/>
  
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137531740-3ede6a8e-e2d3-428e-b4b8-b27ccd54c793.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137532283-6ffcbebc-a7ff-414b-a9e6-68dd5a15bca1.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137531815-0ff9594e-3b2c-4a9a-9400-5a871aa1129f.png">  
  </p>
  
  #### 5.
  어떻게 성능을 더 높일 수 있을까 고민하다, `programmer`에 PK가 없다는 걸 깨달았다.<br/>
  혹시나 싶어서 테이블에 PK를 지정했다.<br/>
  결과적으로 100ms 이하의 쿼리를 만들 수 있었다.<br/>

  ```sql
  alter table programmer
  add primary key(id);
  ```
  <br/>
 
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137529337-42f6b5d1-1c74-4b94-a123-38161f28bcda.png">
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137532093-6b1380e2-3560-48f0-bff3-d8a19151e4cd.png">  
  </p>

</details>

<details>
  <summary>질문</summary>
  <br/>

  커버링 인덱스로 성능을 개선시키는 건 이해했는데, PK를 지정했을 때 성능이 더 개선되는 이유가 궁금합니다.<br/>
  실행 계획을 보면, PK를 추가했을 때 읽는 레코드 양도 늘어나는데 말이죠 🤔<br/>
  검프는 왜 이런지 알고 있나요??<br/>

</details>

<br/>

- [x] 각 프로그래머별로 해당하는 병원 이름을 반환한다.

<details>
  <summary>쿼리 작성</summary>
  <br/>

  ```sql
  select
    programmer.id as '프로그래머',
    hospital.name as '병원명'
  from
    programmer
  join
    covid on programmer.id = covid.programmer_id
  join
    hospital on hospital.id = covid.hospital_id;
  ```
</details>

<details>
  <summary>실행 결과</summary>

  #### 소요 시간
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137592807-c607c411-b1a0-4515-9cdb-1180ce4cf478.png">  
  </p>

  #### 테이블 출력
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137590083-131594fb-61c8-4103-baec-f62c37f0c4fd.png">
  </p>

  #### 실행 계획
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137592818-972d76d4-3e45-47fe-9a38-591436d05935.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137592854-33bf0f40-be0c-4395-afcf-a35be9d4394f.png">  
  </p>

</details>

<details>
  <summary>정리</summary>

  #### 1.
  우선, `programmer`, `covid`, `hospital`에 PK를 추가했다.
  
  ```sql
  alter table programmer
  add primary key(id);

  alter table covid
  add primary key(id);

  alter table hospital
  add primary key(id);
  ```

  #### 2.
  쿼리를 작성하고, 실행 결과를 확인했다.<br/>
  테이블이 기대대로 출력되고, 소요 시간도 요구사항을 충족했다.<br/>

  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137590083-131594fb-61c8-4103-baec-f62c37f0c4fd.png">
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137590168-4ad53151-2fb3-4316-b020-6965e5af3bfe.png">  
  </p>
  <br/>

  이어서 실행 계획도 확인했다.<br/>
  이때, `covid`는 Full Table Scan 중이었다.<br/>

  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137590251-a33216a9-1fe4-4eb4-8e32-2426ba1f6ba0.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137590560-230f67bd-ebaf-4eec-9e18-2c8cc461f19e.png">  
  </p>

  #### 3.
  `covid`의 Full Table Scan을 개선하고 싶었다.<br/>
  그래서 인덱스를 걸어줬다.<br/>

  ```sql
  create index `idx_programmer_id_hospital_id` on covid (programmer_id, hospital_id);
  ```

  #### 4.
  다시 실행 결과와 실행 계획을 확인했다.<br/>
  딱히 소요 시간이 나아지지는 않았고, 오히려 조금 더 늘어났다.<br/>
  대신 `covid`의 Full Table Scan이 없어지고, 커버링 인덱스를 사용하게 됐다.<br/>
  하지만 이번에는 `programmer`가 Full Table Scan을 하게 됐다.<br/>
  `programmer`는 커버링 인덱스를 활용하고 있어 Index Range/Full Scan을 할 것이라 예상했는데 아니었다.<br/>
  
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137592807-c607c411-b1a0-4515-9cdb-1180ce4cf478.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137592818-972d76d4-3e45-47fe-9a38-591436d05935.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137592854-33bf0f40-be0c-4395-afcf-a35be9d4394f.png">  
  </p>
  <br/>

  #### 5.
  소요 시간을 더 개선하고 싶어 `hospital`의 name에 Unique 제약조건도 걸어봤는데, 별로 나아지지 않았다.<br/>
  (기존에 `hospital`의 name 타입이 text로 되어 있어 varchar로 변경하고 제약조건을 추가했다.)<br/>
  결과적으로 100ms 이하의 쿼리이긴 하니깐, 여기까지 실험을 진행하고 마쳤다.<br/>

</details>

<details>
  <summary>질문</summary>
  <br/>

  커버링 인덱스가 적용되고 있는데도 Full Table Scan을 하는 이유는 무엇일까요??<br/>
  커버링 인덱스는 인덱스만으로도 결과를 도출할 수 있어 디스크까지 접근하지 않는다고 이해하고 있는데, 제가 놓친 부분이 있을까요?<br/>
</details>

<br/>

- [x] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬한다.

<details>
  <summary>쿼리 작성</summary>
  <br/>

  ```sql
  select
    programmer.id as '프로그래머',
          hospital.name as '병원명'
  from
    hospital
  join
    covid on hospital.id = covid.hospital_id
  join
    programmer on covid.id = programmer.id
  where
    programmer.hobby = 'Yes' and
    (
        programmer.dev_type = 'Student' or
        programmer.years_coding = '0-2 years'
      )
  order by
    programmer.id;
  ```
</details>

<details>
  <summary>실행 결과</summary>

  #### 소요 시간
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137594833-a548a132-fcaa-4e85-b6e4-304219389151.png">  
  </p>

  #### 테이블 출력
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137594863-c8eefcfa-7b0e-4df8-a074-dd0f4dd2122c.png">
  </p>

  #### 실행 계획
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137594881-63b46bdd-3aa2-4478-897e-82a48ce9d462.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137594907-19d9e3ce-6504-428a-b6e1-baf09d2c2463.png">  
  </p>
</details>

<details>
  <summary>정리</summary>
  
  #### 1.
  이전 문제의 쿼리를 이용할 수 있을 것 같아, 이를 활용해서 쿼리를 작성했다.<br/>
  근데 성능이 생각보다 좋지는 않았다.<br/>
  
  ```sql
  select
    programmer.id as '프로그래머',
          hospital.name as '병원명'
  from
    programmer
  join
    covid on programmer.id = covid.programmer_id
  join
    hospital on hospital.id = covid.hospital_id
  where
    programmer.hobby = 'Yes' and
    (
        programmer.dev_type = 'Student' or
        programmer.years_coding = '0-2 years'
      )
  order by
    programmer.id;
  ```
  <br/>
  
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137594960-1fd151dd-0baf-4e51-8ac3-afa0836e8786.png">  
  </p>
  
  #### 2.
  어떻게 개선해야 하나 고민하다, 모수 테이블을 변경해서 랜덤 액세스를 줄여야겠다고 생각했다.<br/>
  결과는 성공적이었다! 인덱스를 추가하는 것보다 성능이 크게 개선됐다.<br/>
  
  ```sql
  select
    programmer.id as '프로그래머',
    hospital.name as '병원명'
  from
    hospital
  join
    covid on hospital.id = covid.hospital_id
  join
    programmer on covid.id = programmer.id
  where
    programmer.hobby = 'Yes' and
    (
      programmer.dev_type = 'Student' or
      programmer.years_coding = '0-2 years'
    )
  order by
    programmer.id;
  ```
  <br/>
  
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137595156-aa4fac8c-d475-4662-bdcf-a51ec3d12a21.png">  
  </p>

  #### 3.
  한편 실행 계획을 살펴보면 `programmer`가 Full Table Scan을 하고 있고, 커버링 인덱스를 사용하는 테이블이 없었다.<br/>

  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137595208-136773dd-e550-40bc-a01a-143e9a3d9b8c.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137595229-fd294f80-626d-4e17-8a53-0ac0284d2e22.png">  
  </p>

  #### 4.
  그래서 `programmer`에 인덱스를 추가했다. 이때, 커버링 인덱스가 적용되게 만들었다.<br/>
  다만 `programmer`의 dev_type 타입이 text여서 인덱스를 생성할 수 없었다.<br/>
  따라서, 해당 컬럼을 제외하고 인덱스를 걸었다.<br/>

  ```sql
  create index `idx_hobby_years_coding_id` on programmer (hobby, years_coding, id);
  ```
  <br/>
  
  실행 결과와 실행 계획이 만족스럽게 나왔다 🙌<br/>
  
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137595422-bf234cbe-c9ce-4f08-bddd-203af8d24242.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137595433-4a3ffdcb-3157-4531-9a91-b27ce5e50a03.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137595446-9cf8d15f-a6f0-4d62-b70b-615738f47c1d.png">  
  </p>

</details>

<br/>

- [x] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계한다.

<details>
  <summary>쿼리 작성</summary>
  <br/>

  ```sql
  select
    covid.stay as '입원 기간',
    count(covid.stay) as '인원수'
  from
    hospital
  join
    covid on hospital.id = covid.hospital_id
  join
    programmer on covid.programmer_id = programmer.id
  join
    member on programmer.member_id = member.id
  where
    programmer.country = 'India' and
    hospital.name = '서울대병원' and
    member.age between 20 and 29
  group by
    covid.stay
  order by
    null;
  ```

</details>

<details>
  <summary>실행 결과</summary>

  #### 소요 시간
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137596728-25777f08-8656-47a2-8fee-dd294842634a.png">  
  </p>
  
  #### 테이블 출력
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137596858-d329b670-79a3-4b5b-8476-7fc17bab9ce7.png">  
  </p>

  #### 실행 계획
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137596736-d85ddaf2-0163-473c-9170-db8fe0c9fcd9.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137596765-4a9b063d-29c8-411f-9d28-aca956d0e7a1.png">  
  </p>

</details>

<details>
  <summary>정리</summary>
  
  #### 1.
  쿼리를 작성하고, 실행 시간과 실행 계획을 확인했다.<br/>

  ```sql
  select
    covid.stay as '입원 기간',
    count(covid.stay) as '인원수'
  from
    hospital
  join
    covid on hospital.id = covid.hospital_id
  join
    programmer on covid.programmer_id = programmer.id
  join
    member on programmer.member_id = member.id
  where
    programmer.country = 'India' and
    hospital.name = '서울대병원' and
    member.age between 20 and 29
  group by
    covid.stay
  order by
    null;
  ```
  <br/>
  
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137596447-ef832dc6-2dfc-4adc-8ea7-2668a231c2da.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137596461-27065aa1-4006-47f1-a08a-6501e5a2bc4e.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137596469-4232d5ed-7bee-41aa-8486-180a4bc3a331.png">  
  </p>
  
  #### 2.
  인덱스가 PK만 있는 상태에서는 100ms 이하의 쿼리를 만들 수 없었다.<br/>
  그래서 인덱스를 FK 기준으로 추가했다.<br/>

  ```sql
  create index `idx_member_id_country` on programmer (member_id, country);
  create index `idx_hospital_id_programmer_id` on covid (hospital_id, programmer_id);
  ```
  <br/>
  
  이어서 실행 결과와 실행 계획을 확인했다.<br/>
  
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137596589-ac15516e-2956-431f-9ab7-9c472568268b.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137596626-9704b093-ea81-4e82-94b6-fc21bf90bc9a.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137596616-134b104c-11c0-4436-a1d6-8b744bed1652.png">  
  </p>
  
  #### 3.
  `hospital`의 Full Table Scan을 없앨 수 있는 방법이 없을까 고민했다.<br/>
  한번 name 컬럼에 인덱스를 걸어봤고, 결과는 성공적이었다.<br/>

  ```sql
  create index `idx_name` on hospital (name);
  ```
  <br/>
  
  실행 시간도 빨라졌고, 실행 계획도 원하는 모습으로 나타났다.<br/>
  
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137596728-25777f08-8656-47a2-8fee-dd294842634a.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137596736-d85ddaf2-0163-473c-9170-db8fe0c9fcd9.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137596765-4a9b063d-29c8-411f-9d28-aca956d0e7a1.png">  
  </p>

</details>

<br/>  

- [x] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계한다.

<details>
  <summary>쿼리 작성</summary>
  <br/>

  ```sql
  select
      programmer.exercise as '운동 횟수',
      count(programmer.exercise) as '인원수'
  from
      hospital
  join
      covid on hospital.id = covid.hospital_id
  join
      programmer on covid.programmer_id = programmer.id
  join
      member on programmer.member_id = member.id
  where
      hospital.name = '서울대병원' and 
      member.age between 30 and 39
  group by
      programmer.exercise
  order by
      null;
  ```

</details>

<details>
  <summary>실행 결과</summary>

  #### 소요 시간

  #### 테이블 출력

  #### 실행 계획

</details>

<details>
  <summary>정리</summary>

  #### 1.
  앞선 문제와 동일하게 쿼리를 작성하고, 실행 결과와 실행 계획을 확인했다.<br/>

  ```sql
  select
      programmer.exercise as '운동 횟수',
      count(programmer.exercise) as '인원수'
  from
      hospital
  join
      covid on hospital.id = covid.hospital_id
  join
      programmer on covid.programmer_id = programmer.id
  join
      member on programmer.member_id = member.id
  where
      hospital.name = '서울대병원' and 
      member.age between 30 and 39
  group by
      programmer.exercise
  order by
      null;
  ```
  <br/>

  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137597062-53b9f2dd-0b90-44a3-a64f-9d4c08733099.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137597069-0499340d-17e8-4ddb-b653-c1c86d6c0b96.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137597081-a7877f0a-869d-4206-9cf6-7cef785e6d29.png">  
  </p>

  #### 2.
  역시 100ms 초과의 쿼리였다.<br/>
  인덱스를 추가해야겠다고 생각했고, FK를 기준으로 걸어줬다.<br/>

  ```sql
  create index `idx_member_id` on programmer (member_id);
  create index `idx_hospital_id_programmer_id` on covid (hospital_id, programmer_id);
  ```
  <br/>
  
  그리고 실행 시간과 실행 계획을 확인했다.<br/>
  인덱스의 효과가 컸다. 성능이 많이 개선됐다.<br/>
  
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137597202-d5448426-bb93-4be6-8179-03f68d0461ff.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137597210-abf8b0ed-3c78-4a48-badd-60fedcec45e7.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137597221-0736e6e8-7b00-4d66-b43e-b916cc3e216d.png">  
  </p>

  #### 3.
  이번에도 `hospital`의 Full Table Scan을 없애고 싶었다.<br/>
  그래서 또 name 컬럼에 인덱스를 걸어서 해결했다.<br/>
  
  ```sql
  create index `idx_name` on hospital (name);
  ```
  <br/>
  
  커버링 인덱스로 성능을 더 개선시킬 수 있었다! 🥳<br/>

  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137597298-ef67c74e-d136-4e07-b47e-8c85ea2cf2c9.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137597311-ff2e2792-28a6-4b91-9d17-6e26aac7fd15.png">  
  </p>
  <p align="center">
    <img src="https://user-images.githubusercontent.com/50176238/137597333-a99930c8-1a73-4d93-94e9-e4c4916a3ae3.png">  
  </p>

</details>

<br/>

## C. 프로젝트 요구사항

### a. 페이징 쿼리를 적용

### b. Replication 적용
