# B. 인덱스 설계

## Coding as Hobby



create index hobby_idx on programmer(hobby);

select hobby, count(*) / (select count(*) from programmer) "Coding as a Hobby" from programmer group by hobby;





## 각 프로그래머별로 해당하는 병원 이름을 반환하세요





## 프로그래밍이 취미인 학생 혹은 주니어(0~2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요.





## 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요.





## 서울대 병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요 .

