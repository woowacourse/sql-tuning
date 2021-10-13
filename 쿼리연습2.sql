-- Coding as a Hobby 와 같은 결과를 반환하세요.
CREATE INDEX `idx_programmer_hobby`  ON `subway`.`programmer` (hobby);
DROP INDEX `idx_programmer_hobby`  ON `subway`.`programmer`;

ALTER TABLE programmer ADD UNIQUE `id_hobby_unique` (id, hobby);
DROP INDEX `id_hobby_unique`  ON `subway`.`programmer`;

SELECT 
	SUM(CASE WHEN hobby='Yes' THEN percentage ELSE 0 END) as Yes,
	SUM(CASE WHEN hobby='No' THEN percentage ELSE 0 END) as No
FROM ( 
	SELECT hobby, ROUND(COUNT(hobby)*100/(SELECT COUNT(*) FROM programmer) ,1) as percentage FROM subway.programmer GROUP BY hobby ORDER BY null
) tb_derived;

SELECT * FROM subway.hospital;
-- 프로그래머별로 해당하는 병원 이름을 반환하세요. (covid.id, hospital.name)
SELECT covid.id AS covid_id, hospital.name AS hospital_name
FROM subway.hospital
	JOIN covid ON covid.hospital_id = hospital.id
	JOIN programmer ON programmer.id = covid.programmer_id;

-- 프로그래밍이 취미인 학생 혹은 주니어(0-2년)들이 다닌 병원 이름을 반환하고 user.id 기준으로 정렬하세요. (covid.id, hospital.name, user.Hobby, user.DevType, user.YearsCoding)
SELECT 
    covid.id,
    hospital.name,
    user.Hobby,
    user.Dev_Type,
    user.Years_Coding,
    user.student
FROM
    subway.covid
        JOIN
    hospital ON hospital.id = covid.hospital_id
        JOIN
    programmer AS user ON user.id = covid.programmer_id
WHERE
    (user.hobby = 'Yes'
        AND user.student <> 'NO'
        AND user.student <> 'NA')
        OR (user.years_coding = '0-2 years')
;

-- 서울대병원에 다닌 20대 India 환자들을 병원에 머문 기간별로 집계하세요. (covid.Stay)
-- EXPLAIN
SELECT 
    stay, COUNT(stay)
FROM (SELECT id FROM subway.member WHERE age BETWEEN 20 AND 29) AS M
INNER JOIN (SELECT programmer_id, member_id, stay FROM covid) AS C ON C.member_id = M.id
INNER JOIN (SELECT id, member_id FROM programmer WHERE country = 'India') AS P ON P.id = C.programmer_id
GROUP BY stay;

SELECT patient_id, covid.Stay, city_code_patient
FROM subway.covid;
    
-- 서울대병원에 다닌 30대 환자들을 운동 횟수별로 집계하세요. (user.Exercise)
SELECT exercise, COUNT(exercise)
FROM (SELECT id FROM subway.member WHERE age BETWEEN 30 AND 39) AS M
INNER JOIN (SELECT id, member_id, hospital_id, programmer_id FROM covid) AS C ON C.member_id = M.id
INNER JOIN (SELECT id, exercise FROM programmer) AS P ON P.id = C.programmer_id
INNER JOIN (SELECT id, name FROM hospital WHERE name = '서울대병원') AS H ON H.id = C.hospital_id
GROUP BY exercise;
