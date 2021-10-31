# A. 쿼리 연습

```SQL
SELECT a.사원번호 사원번호, a.이름 이름, a.연봉 연봉, a.직급명 직급명, b.지역 지역, a.입출입구분 입출입구분, a.입출입시간 입출입시간  
FROM (SELECT e.사원번호 사원번호, e.이름 이름, MAX(s.연봉) 연봉, MAX(c.입출입시간) 입출입시간, c.입출입구분, p.직급명 직급명 FROM 부서관리자 dm   
JOIN 부서 AS d ON d.부서번호 = dm.부서번호  
JOIN 사원 AS e ON e.사원번호 = dm.사원번호  
JOIN 직급 AS p ON p.사원번호 = e.사원번호  
JOIN 급여 AS s ON s.사원번호 = e.사원번호  
JOIN 사원출입기록 AS c ON e.사원번호 = c.사원번호  
WHERE d.비고 = "active" AND dm.종료일자 = "9999-01-01" AND p.종료일자 = "9999-01-01" AND c.입출입구분 = "O" GROUP BY 사원번호, 직급명) a  
JOIN 사원출입기록 AS b ON a.사원번호 = b.사원번호 AND a.입출입시간 = b.입출입시간 ORDER BY 연봉 DESC LIMIT 5;
```  

인덱스  

```SQL
CREATE INDEX idx_enter ON 사원출입기록(사원번호, 입출입구분);  
CREATE INDEX idx_department ON 부서(비고);  
CREATE INDEX idx_employee ON 직급(종료일자);  
```

실행결과  
  
![result](./QueryPractice.png)  
<br>
<br>
![result](./Query-Practice-Result.png)

