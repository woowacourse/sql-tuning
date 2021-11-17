# 🚀 조회 성능 개선하기

## 쿼리 연습

- [ ] 활동중인(Active) 부서의 현재 부서관리자 중 연봉 상위 5위안에 드는 사람들이 최근에 각 지역별로 언제 퇴실했는지 조회해보세요.
(사원번호, 이름, 연봉, 직급명, 지역, 입출입구분, 입출입시간)
- [ ] 주어진 데이터셋을 활용하여 아래 조회 결과를 100ms 이하로 반환
- [ ] [Coding as a  Hobby](https://insights.stackoverflow.com/survey/2018#developer-profile-_-coding-as-a-hobby) 와 같은 결과를 반환하세요.
- [ ] 각 프로그래머별로 해당하는 병원 이름을 반환하세요.  (covid.id, hospital.name)
- [ ] 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)
- [ ] 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)
- [ ] 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)


### 인덱스 손익 분기점 :: 5. 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요.md 중에서..

재밌는게 이전의 full table scan을 제거할 수 있었는데 duration은 더 증가함을 보였다.
인덱스를 태울 때는 10~15% 정도의 분포도를 갖고 있는 데이터를 엑세스 할 때 효율적임을 보여주는 포인트인가 보다.

겉핥기로 공부한 바를 정리해보면 DB의 데이터는 OS의 Disk Block 다발로 이뤄진 Data Block을 저장하는 식이고, 인덱스는 각 Block들의 id를 따로 테이블을 분리해서 저장해두는 방식이라고 이해했다. 그 저장 방식 중에 대표적인게 B-tree 방식인거고. 이 인덱스를 통해 알게 된 Block ID에 해당하는 블록을 엑세스하는 방식인 것이다.

문제는 Full table scan으로 block을 엑세스하면 한번의 엑세스로 block 다발을 가져올 수 있는데 (이 다발의 수 역시 따로 저장되어 있다고 이해했다.), Index을 이용한 탐색의 경우에는 block id를 보고 block을 엑세스한다. 따라서 index를 태워서 효율적이려면 block 다발을 엑세스하는 것보다 여러 엑세스로 단일 블록을 가져올 때 속도가 더 빨라야하느 것이다. 그 정도를 보통 10% ~ 15%로 얘기하는 것 같다. 대량 데이터 접근에도 마찬가지다. 같은 이유로 일반적으로 Full table scan이 유리하다.



