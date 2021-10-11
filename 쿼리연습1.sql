SELECT 사원.사원번호, 사원.이름, 급여.연봉, 직급.직급명
FROM 사원
JOIN 급여 ON 급여.사원번호 = 사원.사원번호
JOIN 직급 ON 직급.사원번호 = 급여.사원번호
JOIN 부서관리자 ON 부서관리자.사원번호 = 직급.사원번호
JOIN 부서 ON 부서.부서번호 = 부서관리자.부서번호
WHERE 급여.종료일자 = '9999-01-01' and 직급.종료일자 = '9999-01-01' 
	and 직급.직급명 ='Manager' and 부서.비고 = 'active'
ORDER BY 급여.연봉 desc
LIMIT 0,5;
 
explain SELECT `높은_연봉의_사원`.사원번호, `높은_연봉의_사원`.이름, `높은_연봉의_사원`.연봉, `높은_연봉의_사원`.직급명, 사원출입기록.입출입시간, 사원출입기록.지역, 사원출입기록.입출입구분
FROM (SELECT 사원.사원번호, 사원.이름, 급여.연봉, 직급.직급명
		FROM 사원
			JOIN 급여 ON 급여.사원번호 = 사원.사원번호
			JOIN 직급 ON 직급.사원번호 = 급여.사원번호
			JOIN 부서관리자 ON 부서관리자.사원번호 = 직급.사원번호
			JOIN 부서 ON 부서.부서번호 = 부서관리자.부서번호
		WHERE 급여.종료일자 = '9999-01-01' and 직급.종료일자 = '9999-01-01' 
			and 직급.직급명 = 'Manager' and 부서.비고 = 'active'
		ORDER BY 급여.연봉 desc 
		LIMIT 0,5) as `높은_연봉의_사원`
	JOIN 사원출입기록 ON 사원출입기록.사원번호 = `높은_연봉의_사원`.사원번호
WHERE 사원출입기록.입출입구분 = 'O' 
ORDER BY `높은_연봉의_사원`.연봉 desc, 사원출입기록.입출입시간 desc;

CREATE INDEX `idx_사원_입출입구분_사원`  ON `tuning`.`사원출입기록` (사원번호,입출입구분);

CREATE INDEX `idx_부서_비고_부서번호`  ON `tuning`.`부서` (비고, 부서번호);

CREATE INDEX `idx_부서관리자_사원번호_부서번호`  ON `tuning`.`부서관리자` (사원번호, 부서번호);

CREATE INDEX `idx_부서관리자_사원번호_부서번호`  ON `tuning`.`부서관리자` (부서번호, 사원번호);

DROP INDEX `idx_사원_입출입구분_사원`   ON `tuning`.`사원출입기록`;

DROP INDEX `idx_부서관리자_사원번호_부서번호`  ON `tuning`.`부서관리자`;

DROP INDEX `idx_부서_비고_부서번호` ON `tuning`.`부서`;