--------Drops----------
DROP TABLE "work";
DROP TABLE "hospitalization";
DROP TABLE "drug_used";
DROP TABLE "examination";

DROP TABLE "employee";
DROP TABLE "department";
DROP TABLE "patient";
DROP TABLE "drug";



--------CREATE---------
CREATE TABLE "department" (
	"id" INT GENERATED AS IDENTITY NOT NULL PRIMARY KEY,
	"name" VARCHAR(255) NOT NULL
);

CREATE TABLE "patient" (
	"id" INT PRIMARY KEY,
    "birth_code" VARCHAR(10) NOT NULL,
    CHECK( REGEXP_LIKE(
			"birth_code", '^\d{10}$', 'i'
		)),
	"first_name" VARCHAR(255) NOT NULL,
    "surename" VARCHAR(255) NOT NULL,
    "gender" VARCHAR(10) NOT NULL,
    CHECK ("gender" IN ('muž', 'žena')),
    "birth_date" DATE NOT NULL
);

------ TRIGGER ------
-- pacient, ktory sa este nenarodil nemoze byt vlozeny 
CREATE OR REPLACE TRIGGER "check_birth_date"
    BEFORE INSERT ON "patient"
    FOR EACH ROW
DECLARE
    temp_date DATE;
BEGIN
    temp_date := TO_DATE(SYSDATE, 'YYYY-MM-DD');
    IF( :NEW."birth_date" > SYSDATE)
    THEN 
        RAISE_APPLICATION_ERROR(-20000, 'Invalid date of birth.');
    END IF;
END;
/

------TRIGGER --------
--generovanie indexu pre pacienta
CREATE OR REPLACE TRIGGER Id_generated
    BEFORE INSERT ON "patient"
    FOR EACH ROW
DECLARE
    tmp_id INT;
    tmp_cnt INT;
BEGIN
    IF :NEW."id" is NULL
    THEN
        SELECT count(*) INTO tmp_cnt
        From "patient" ;
    
        IF tmp_cnt = 0
        THEN 
            :NEW."id" := 1;
        ELSE
            SELECT p."id" INTO tmp_id
            FROM "patient" p
            WHERE ROWNUM <= 1
            ORDER BY p."id" DESC;
            :NEW."id" := tmp_id + 1;
        END IF;
    END IF;
END;
/

CREATE TABLE "drug" (
	"id" INT GENERATED AS IDENTITY NOT NULL PRIMARY KEY,
	"name" VARCHAR(255) NOT NULL,
    "manufacturer" VARCHAR(255) NOT NULL,
    "content" VARCHAR(1024) NOT NULL,
    "informations" VARCHAR(1024) NOT NULL
);

CREATE TABLE "employee" (
	"id" INT GENERATED AS IDENTITY NOT NULL PRIMARY KEY,
	"first_name" VARCHAR(255) NOT NULL,
    "surename" VARCHAR(255) NOT NULL,
    "gender" VARCHAR(10) NOT NULL,
    CHECK ("gender" IN ('muž', 'žena')),
    "birth_date" DATE NOT NULL,
    "type" VARCHAR(10) NOT NULL,
    CHECK ("type" IN ('doktor', 'sestra')),
    --for doctor
    "specification" VARCHAR(255) DEFAULT NULL,
    --for nurse
    "depart_id" INT DEFAULT NULL, 
    CONSTRAINT "depat_id_empl_fk" 
        FOREIGN KEY ("depart_id") REFERENCES "department" ("id")
        ON DELETE CASCADE,
    "position" VARCHAR(255) DEFAULT NULL,
    "salary" INT DEFAULT NULL, 
    "worked_hours" INT DEFAULT NULL,
    CHECK ("type"='doktor' AND "specification" IS NOT NULL OR 
            "type"='sestra' AND "position" IS NOT NULL AND "salary" > 0 AND "worked_hours" IS NOT NULL AND "depart_id" IS NOT NULL)
);

CREATE TABLE "work"(
    "id" INT GENERATED AS IDENTITY NOT NULL PRIMARY KEY,
    "doctor_id" INT NOT NULL,
    "depart_id" INT NOT NULL,
    "phone" INT NOT NULL,
    "work_time" VARCHAR(100) NOT NULL,
    "salary" INT NOT NULL,
    CHECK ("salary" > 0),
    "worked_hours" INT DEFAULT NULL,
    CONSTRAINT "doctor_id_fk"
		FOREIGN KEY ("doctor_id") REFERENCES "employee" ("id")
		ON DELETE CASCADE,
    CONSTRAINT "depart_id_fk"
		FOREIGN KEY ("depart_id") REFERENCES "department" ("id")
		ON DELETE CASCADE
);


------TRIGGER--------
--Uvazok Work je medzi doktorom a oddelenim,skontroluje typ emploeey
CREATE OR REPLACE TRIGGER Is_doctor
    BEFORE INSERT ON "work"
    FOR EACH ROW
DECLARE    
    emp_type VARCHAR(10);
BEGIN
    SELECT e."type" INTO emp_type
    FROM "employee" e
    WHERE e."id" = :NEW."doctor_id";
    
    IF emp_type != 'doktor'
    THEN
        raise_application_error(-20101, 'ERROR: Vytvorit uvazok nie je mozne 
                        pre sestru. Skontroluj ci si vlozil spravne doctor_id');
    END IF;
END;
/

CREATE TABLE "hospitalization"(
    "id" INT GENERATED AS IDENTITY NOT NULL PRIMARY KEY,
    "patient_id" INT NOT NULL,
    "depart_id" INT NOT NULL,
    "doctor_id" INT NOT NULL,
    "start" DATE NOT NULL,
    "end" DATE DEFAULT NULL,
    
     CONSTRAINT "patient_id_hos_fk"
		FOREIGN KEY ("patient_id") REFERENCES "patient" ("id")
		ON DELETE CASCADE,
    CONSTRAINT "depart_id_hos_fk"
		FOREIGN KEY ("depart_id") REFERENCES "department" ("id")
		ON DELETE SET NULL,
    CONSTRAINT "doctor_id_hos_fk"
		FOREIGN KEY ("doctor_id") REFERENCES "employee" ("id")
		ON DELETE SET NULL
);

------ TRIGGER ------
-- pacient nemoze byt hospitalizovany na viacerych oddeleniach v jednu chvilu
CREATE OR REPLACE TRIGGER "check_hospitalization"
    BEFORE INSERT ON "hospitalization"
    FOR EACH ROW
DECLARE 
     temp INT;
BEGIN
    SELECT count(*) INTO temp
    FROM "hospitalization" h
    WHERE ((:NEW."start" >= h."start" AND :NEW."start" < h."end") OR 
            (:NEW."end" > h."start" AND :NEW."end" <= h."end") 
           OR (:NEW."start" <= h."start" AND h."start" < :NEW."end") OR 
            (:NEW."end" > h."end" AND h."end" >= :NEW."start")) AND 
            :NEW."patient_id" = h."patient_id";
    
    IF(temp > 0)
    THEN 
        RAISE_APPLICATION_ERROR(-20000, 'Patient already laying on some 
            department.');
    END IF;
END;
/

CREATE TABLE "drug_used"(
    "id" INT GENERATED AS IDENTITY NOT NULL PRIMARY KEY,
    "patient_id" INT NOT NULL,
    "drug_id" INT NOT NULL,
    "doctor_id" INT NOT NULL,
    "start" DATE NOT NULL,
    "end" DATE DEFAULT NULL,
    "usage" VARCHAR(128) NOT NULL,
    
    CONSTRAINT "patient_id_drug_fk"
		FOREIGN KEY ("patient_id") REFERENCES "patient" ("id")
		ON DELETE CASCADE,
    CONSTRAINT "drug_id_drug_fk"
		FOREIGN KEY ("drug_id") REFERENCES "drug" ("id")
		ON DELETE SET NULL,
    CONSTRAINT "doctor_id_drug_fk"
		FOREIGN KEY ("doctor_id") REFERENCES "employee" ("id")
		ON DELETE SET NULL

);

CREATE TABLE  "examination"(
    "id" INT GENERATED AS IDENTITY NOT NULL PRIMARY KEY,
    "patient_id" INT NOT NULL,
    "depart_id" INT NOT NULL,
    "doctor_id" INT NOT NULL,
    "date" TIMESTAMP NOT NULL,
    "result" VARCHAR(1024) DEFAULT NULL,
    
    CONSTRAINT "patient_id_exam_fk"
		FOREIGN KEY ("patient_id") REFERENCES "patient" ("id")
		ON DELETE CASCADE,
    CONSTRAINT "depart_id_exam_fk"
		FOREIGN KEY ("depart_id") REFERENCES "department" ("id")
		ON DELETE SET NULL,
    CONSTRAINT "doctor_id_exam_fk"
		FOREIGN KEY ("doctor_id") REFERENCES "employee" ("id")
		ON DELETE SET NULL
);

--------INSERTS------------

INSERT INTO "department" ("name")
VALUES ('Urgent');
INSERT INTO "department" ("name")
VALUES ('Pediatria');
INSERT INTO "department" ("name")
VALUES ('Chirurgia');
INSERT INTO "department" ("name")
VALUES ('Jednotka intenzívnej starostlivosti');


INSERT INTO "patient" ("birth_code", "first_name", "surename", "gender", "birth_date")
VALUES ('9908224832', 'Jakub', 'Sokolík', 'muž', TO_DATE('1999-08-22', 'YYYY-MM-DD'));
INSERT INTO "patient" ("birth_code", "first_name", "surename", "gender", "birth_date")
VALUES ('9005084891', 'Ferko', 'Mrkvièka', 'muž', TO_DATE('1990-05-08', 'YYYY-MM-DD'));
INSERT INTO "patient" ("birth_code", "first_name", "surename", "gender", "birth_date")
VALUES ('0002137325', 'Štefan', 'Koval', 'muž', TO_DATE('2000-02-13', 'YYYY-MM-DD'));
INSERT INTO "patient" ("birth_code", "first_name", "surename", "gender", "birth_date")
VALUES ('7712122589', 'Jano', 'Sádecký', 'muž', TO_DATE('1977-12-12', 'YYYY-MM-DD'));
INSERT INTO "patient" ("birth_code", "first_name", "surename", "gender", "birth_date")
VALUES ('9055084891', 'Janka', 'Novanská', 'žena', TO_DATE('1990-05-08', 'YYYY-MM-DD'));
INSERT INTO "patient" ("birth_code", "first_name", "surename", "gender", "birth_date")
VALUES ('9858074369', 'Danka', 'Novanská', 'žena', TO_DATE('1990-08-07', 'YYYY-MM-DD'));
INSERT INTO "patient" ("birth_code", "first_name", "surename", "gender", "birth_date")
VALUES ('9155084258', 'Klára', 'Staraková', 'žena', TO_DATE('1991-05-08', 'YYYY-MM-DD'));

---Vlozenie nenarodeneho pacienta, trigger by mal kricat
INSERT INTO "patient" ("birth_code", "first_name", "surename", "gender", "birth_date")
VALUES ('9908224832', 'Jakub', 'Sokolík', 'muž', TO_DATE('2022-08-22', 'YYYY-MM-DD'));

INSERT INTO "drug" ("name", "manufacturer", "content", "informations")
VALUES ('Stoptusin', 'TEVA', 'butamirátiumdihydrogéncitrát 0,8mg, guajfenezim 0,25mg', 'nekombinovat s alkoholom');
INSERT INTO "drug" ("name", "manufacturer", "content", "informations")
VALUES ('Paralen', 'Sanofi','paracetamol 0,8mg', 'nevhodné pre deti do 6r');
INSERT INTO "drug" ("name", "manufacturer", "content", "informations")
VALUES ('Dorithricin', 'TEVA', 'tyrotricín 0,2mg, benzokain 1,5mg, benzalkóniumchlorid 1,0mg', 'nevhodné pre tehotné a dojèiace Ženy');

INSERT INTO "employee" ("first_name", "surename", "gender", "birth_date", "type", "specification")
VALUES ('Veronika', 'Chytrá', 'žena', TO_DATE('1984-05-08', 'YYYY-MM-DD'), 'doktor', 'traumatológ');
INSERT INTO "employee" ("first_name", "surename", "gender", "birth_date", "type", "specification")
VALUES ('Fero', 'Pócs', 'muž', TO_DATE('1964-11-24', 'YYYY-MM-DD'), 'doktor', 'chirurg');
INSERT INTO "employee" ("first_name", "surename", "gender", "birth_date", "type", "specification")
VALUES ('Teodor', 'Chudý', 'muž', TO_DATE('1976-03-11', 'YYYY-MM-DD'), 'doktor', 'pediater');
INSERT INTO "employee" ("first_name", "surename", "gender", "birth_date", "type", "specification")
VALUES ('Teodor', 'Roosvelt', 'muž', TO_DATE('1972-06-19', 'YYYY-MM-DD'), 'doktor', 'pediater');
INSERT INTO "employee" ("first_name", "surename", "gender", "birth_date", "type", "position", "salary", "worked_hours", "depart_id")
VALUES ('Magdaléna', 'Truchlá', 'žena', TO_DATE('1981-06-13', 'YYYY-MM-DD'), 'sestra', 'vrchná sestra', '29000', '124', '1');
INSERT INTO "employee" ("first_name", "surename", "gender", "birth_date", "type", "position", "salary", "worked_hours", "depart_id")
VALUES ('Adriana', 'Lieskovská', 'žena', TO_DATE('1981-04-23', 'YYYY-MM-DD'), 'sestra', 'vrchná sestra', '23000', '96', '2');
INSERT INTO "employee" ("first_name", "surename", "gender", "birth_date", "type", "position", "salary", "worked_hours", "depart_id")
VALUES ('Kamila', 'Kvasnicová', 'žena', TO_DATE('1989-12-24', 'YYYY-MM-DD'), 'sestra', 'sestra', '24500', '102', '2');
INSERT INTO "employee" ("first_name", "surename", "gender", "birth_date", "type", "position", "salary", "worked_hours", "depart_id")
VALUES ('Adam', 'Damek', 'muž', TO_DATE('1987-01-27', 'YYYY-MM-DD'), 'sestra', 'sestra', '22500', '94', '1');

INSERT INTO "work" ("doctor_id", "depart_id", "phone", "work_time", "worked_hours", "salary")
VALUES ('1', '1', '+421090090090', 'po-str 6:30-14:00', '48', '16000');
INSERT INTO "work" ("doctor_id", "depart_id", "phone", "work_time", "worked_hours", "salary")
VALUES ('1', '2', '+421090090091', 'št-pi 6:30-14:00', '36', '12000');
INSERT INTO "work" ("doctor_id", "depart_id", "phone", "work_time", "worked_hours", "salary")
VALUES ('2', '3', '+421090090090', 'po-str 6:30-14:00 pia 11:00-18:00', '88', '22000');
INSERT INTO "work" ("doctor_id", "depart_id", "phone", "work_time", "worked_hours", "salary")
VALUES ('2', '4', '+421777111222', 'št 12:00-18:00', '16', '4500');
INSERT INTO "work" ("doctor_id", "depart_id", "phone", "work_time", "worked_hours", "salary")
VALUES ('3', '1', '+421777111223', 'št 12:00-18:00', '24', '4500');
INSERT INTO "work" ("doctor_id", "depart_id", "phone", "work_time", "worked_hours", "salary")
VALUES ('4', '1', '+421777111228', 'št 12:00-18:00', '18', '4500');
-----VLOzenie sestry, triger by mal hodit error
INSERT INTO "work" ("doctor_id", "depart_id", "phone", "work_time", "worked_hours", "salary")
VALUES ('8', '1', '+421090090090', 'po-str 6:30-14:00', '48', '16000');

INSERT INTO "hospitalization" ("patient_id", "doctor_id", "depart_id", "start", "end")
VALUES ('1', '3', '4', TO_DATE('2021-03-02', 'YYYY-MM-DD'), TO_DATE('2021-03-08', 'YYYY-MM-DD'));
INSERT INTO "hospitalization" ("patient_id", "doctor_id", "depart_id", "start", "end")
VALUES ('1', '2', '1', TO_DATE('2021-03-09', 'YYYY-MM-DD'), TO_DATE('2021-03-18', 'YYYY-MM-DD'));
INSERT INTO "hospitalization" ("patient_id", "doctor_id", "depart_id", "start", "end")
VALUES ('5', '1', '1', TO_DATE('2021-03-14', 'YYYY-MM-DD'), TO_DATE('2021-03-18', 'YYYY-MM-DD'));
INSERT INTO "hospitalization" ("patient_id", "doctor_id", "depart_id", "start")
VALUES ('4', '2', '4', TO_DATE('2021-03-22', 'YYYY-MM-DD'));
INSERT INTO "hospitalization" ("patient_id", "doctor_id", "depart_id", "start")
VALUES ('2', '2', '1', TO_DATE('2021-03-22', 'YYYY-MM-DD'));
INSERT INTO "hospitalization" ("patient_id", "doctor_id", "depart_id", "start", "end")
VALUES ('6', '4', '1', TO_DATE('2021-02-16', 'YYYY-MM-DD'), TO_DATE('2021-03-01', 'YYYY-MM-DD'));
-----vlozenie zlej hodnoty, trigger by mal kricat
INSERT INTO "hospitalization" ("patient_id", "doctor_id", "depart_id", "start", "end")
VALUES ('1', '3', '4', TO_DATE('2021-03-07', 'YYYY-MM-DD'), TO_DATE('2021-03-12', 'YYYY-MM-DD'));

INSERT INTO "drug_used" ("patient_id", "drug_id", "doctor_id", "start", "end", "usage")
VALUES ('2', '2', '4', TO_DATE('2021-03-22', 'YYYY-MM-DD'), TO_DATE('2021-03-29', 'YYYY-MM-DD'), 'jedna ráno');
INSERT INTO "drug_used" ("patient_id", "drug_id", "doctor_id", "start", "end", "usage")
VALUES ('4', '1', '1', TO_DATE('2021-02-22', 'YYYY-MM-DD'), TO_DATE('2021-03-22', 'YYYY-MM-DD'), 'jedna ráno aj vecer');
INSERT INTO "drug_used" ("patient_id", "drug_id", "doctor_id", "start", "end", "usage")
VALUES ('1', '2', '3', TO_DATE('2021-02-22', 'YYYY-MM-DD'), TO_DATE('2021-03-01', 'YYYY-MM-DD'), 'jedna ráno');
INSERT INTO "drug_used" ("patient_id", "drug_id", "doctor_id", "start", "end", "usage")
VALUES ('2', '2', '2', TO_DATE('2021-03-08', 'YYYY-MM-DD'), TO_DATE('2021-03-15', 'YYYY-MM-DD'), '30ml vecer');
INSERT INTO "drug_used" ("patient_id", "drug_id", "doctor_id", "start", "end", "usage")
VALUES ('7', '2', '3', TO_DATE('2021-03-14', 'YYYY-MM-DD'), TO_DATE('2021-03-21', 'YYYY-MM-DD'), 'jedna rano/vecer');

INSERT INTO "examination" ("patient_id", "doctor_id", "depart_id", "date", "result")
VALUES ('4', '3', '4', TO_TIMESTAMP('2021-03-02 07:00', 'YYYY-MM-DD HH24:MI.FF3'), 'Fraktura ¾avej ruky v oblati vretnnej kosti');
INSERT INTO "examination" ("patient_id", "doctor_id", "depart_id", "date", "result")
VALUES ('3', '2', '1', TO_TIMESTAMP('2021-02-22 09:30', 'YYYY-MM-DD HH24:MI.FF3'), 'Zápal slepeho èreva');
INSERT INTO "examination" ("patient_id", "doctor_id", "depart_id", "date")
VALUES ('1', '2', '2', TO_TIMESTAMP('2021-03-17 08:00', 'YYYY-MM-DD HH24:MI.FF3'));
INSERT INTO "examination" ("patient_id", "doctor_id", "depart_id", "date")
VALUES ('3', '4', '3', TO_TIMESTAMP('2021-03-18 18:00', 'YYYY-MM-DD HH24:MI.FF3'));
INSERT INTO "examination" ("patient_id", "doctor_id", "depart_id", "date", "result")
VALUES ('1', '2', '2', TO_TIMESTAMP('2021-02-18 13:00', 'YYYY-MM-DD HH24:MI.FF3'), 'CT odhalilo nádor na mozgu');
INSERT INTO "examination" ("patient_id", "doctor_id", "depart_id", "date")
VALUES ('1', '3', '4', TO_TIMESTAMP('2021-03-22 11:00', 'YYYY-MM-DD HH24:MI.FF3'));
INSERT INTO "examination" ("patient_id", "doctor_id", "depart_id", "date", "result")
VALUES ('1', '1', '1', TO_TIMESTAMP('2021-01-11 22:30', 'YYYY-MM-DD HH24:MI.FF3'), 'Fraktura praveho zapestia');
INSERT INTO "examination" ("patient_id", "doctor_id", "depart_id", "date", "result")
VALUES ('4', '1', '1', TO_TIMESTAMP('2021-02-13 17:30', 'YYYY-MM-DD HH24:MI.FF3'), 'Fraktura stehennej kosti na lavej nohe');
INSERT INTO "examination" ("patient_id", "doctor_id", "depart_id", "date")
VALUES ('6', '2', '4', TO_TIMESTAMP('2021-03-22 17:45', 'YYYY-MM-DD HH24:MI.FF3'));


--------PROCEDURES------------
-- procedura vypise priemerny plat sestriciek
CREATE OR REPLACE PROCEDURE "average_income_nurse"
AS 
    "average_income" NUMBER;
    "temp_income" NUMBER;
    "nurse_count" INT;
    CURSOR "cursor_average_salary" IS SELECT "salary" FROM "employee" WHERE "type" = 'sestra';
BEGIN
    SELECT COUNT(*) INTO "nurse_count" 
    FROM "employee" 
    WHERE "type" = 'sestra';
    
    "average_income" := 0;
    
    OPEN "cursor_average_salary";
    LOOP
        FETCH "cursor_average_salary" INTO "temp_income";
        EXIT WHEN "cursor_average_salary"%NOTFOUND;
        "average_income" := "average_income" + "temp_income";
    END LOOP;
    CLOSE "cursor_average_salary";
    
    DBMS_OUTPUT.put_line("average_income"/"nurse_count");
    
    EXCEPTION WHEN ZERO_DIVIDE THEN
    BEGIN
		IF "nurse_count" = 0 THEN
			DBMS_OUTPUT.put_line('Zero nurses in hospital.');
		END IF;
	END;
END;
/
--spustenie procedury
BEGIN "average_income_nurse";
END;
/

--vypise statistiky oddeleia -pocet hospitalizcii a pocet vysetreni
CREATE OR REPLACE PROCEDURE Department_stat
    (depart_name IN VARCHAR)
AS
    all_hospit INT;
    all_exam INT;
    hospit_cnt INT;
    exam_cnt INT;
    depart_id "hospitalization"."depart_id"%TYPE;
    tmp_depart_id "hospitalization"."depart_id"%TYPE;  
    CURSOR cursor_exam IS SELECT "depart_id" FROM "examination";
    CURSOR cursor_depart IS SELECT "depart_id" FROM "hospitalization";
BEGIN
    SELECT count(*) INTO all_hospit
    FROM "hospitalization";
    
    SELECT count(*) INTO all_exam
    FROM "examination";
    
    SELECT d."id" INTO depart_id
    FROM "department" d
    WHERE d."name" = depart_name;
    
    hospit_cnt := 0;
    exam_cnt := 0;
    
    OPEN cursor_depart;
    LOOP
        FETCH cursor_depart INTO tmp_depart_id;
        
        EXIT WHEN cursor_depart%NOTFOUND;
        
        IF tmp_depart_id = depart_id
        THEN
            hospit_cnt := hospit_cnt + 1;
        END IF;
        
    END LOOP;
    CLOSE cursor_depart;
        
    DBMS_OUTPUT.put_line(
        'In ' || depart_name || ' department were ' || hospit_cnt || ' hospitalization from total count ' || all_hospit
    );
        
    OPEN cursor_exam;
    LOOP
        FETCH cursor_exam INTO tmp_depart_id;
        
        EXIT WHEN cursor_exam%NOTFOUND;
        
        IF tmp_depart_id = depart_id
        THEN
            exam_cnt := exam_cnt + 1;
        END IF;
        
    END LOOP;
    CLOSE cursor_exam;
    
    DBMS_OUTPUT.put_line(
			'In ' || depart_name || ' department were ' || exam_cnt || ' examination from total count ' || all_exam
		);
        
    EXCEPTION WHEN NO_DATA_FOUND THEN
    BEGIN
        DBMS_OUTPUT.put_line(
            'Department ' || depart_name || ' dont exist!'
            );
    END;
END;
/
--spustenie procedury
BEGIN Department_stat('Urgent'); 
END;
/

-------------EXLAIN PLAN-------------------------

EXPLAIN PLAN FOR
    SELECT p."first_name" AS meno, p."surename" AS priezvisko, COUNT(e."patient_id") AS pocet
    FROM "patient" p
    JOIN "examination" e ON e."patient_id" = p."id"
    WHERE p."surename" LIKE 'S%'
    GROUP BY p."first_name", p."surename"
    HAVING COUNT(e."patient_id") > 1
    ORDER BY pocet DESC, priezvisko, meno;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

CREATE INDEX "user_surename" ON "patient" ("id", "first_name", "surename");
--DROP INDEX "user_surename";
CREATE INDEX "examination_index" ON "examination" ("patient_id");
--DROP INDEX "examination_index";
EXPLAIN PLAN FOR
    SELECT p."first_name" AS meno, p."surename" AS priezvisko, COUNT(e."patient_id") AS pocet
    FROM "patient" p
    JOIN "examination" e ON e."patient_id" = p."id"
    WHERE p."surename" LIKE 'S%'
    GROUP BY p."first_name", p."surename"
    HAVING COUNT(e."patient_id") > 1
    ORDER BY pocet DESC, priezvisko, meno;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

--------SELECTS--------------

--vybrat vsetkych pacientov, boli vyšetrený v marci.
--spojenie 2 tabuliek.
SELECT p."first_name", p."surename", e."date", e."result" 
FROM "patient" p, "examination" e
WHERE p."id" = e."patient_id" AND EXTRACT(MONTH FROM e."date") = 3;

--vybrat vsetkych sestry, ktoré robia na urgente.
--spojenie 2 tabuliek.
SELECT e.* FROM "employee" e
JOIN "department" d ON e."depart_id" = d."id"
WHERE d."name" = 'Urgent';

--vybra? všetkých pacientov, ktorý uživáli alebo uzivali paralen
--spojenie 3 tabuliek
SELECT p.*, u."start" AS zac, u."end" AS kon
FROM "patient" p, "drug" d, "drug_used" u
Where p."id" = u."patient_id" AND u."drug_id" = d."id" AND d."name" = 'Paralen'
ORDER BY zac, kon;

-- pacienti, ktori su alebo boli hospitalizovani na urgente
--spojenie 3 tabuliek
SELECT p."first_name", p."surename", h."start" AS zaciatok, h."end" AS koniec
FROM "patient" p
JOIN "hospitalization" h ON h."patient_id" = p."id"
JOIN "department" d ON d."id" = h."depart_id"
WHERE d."name"='Urgent'
ORDER BY zaciatok, koniec;

-- kolko v nemocnici pracuje doktorov a kolko sestier
--grup by + agregreg f.
SELECT e."type", COUNT(e."type") AS "count"
FROM "employee" e
GROUP BY e."type";

--pacienti, ktorý boli vyšetrený na viac ako 1 krat, ko¾ko krat
--grup by + agregreg f.
SELECT p."first_name" AS meno, p."surename" AS priezvisko, COUNT(e."patient_id") AS pocet
FROM "patient" p
JOIN "examination" e ON e."patient_id" = p."id"
WHERE p."surename" LIKE 'S%'
GROUP BY p."first_name", p."surename"
HAVING COUNT(e."patient_id") > 1
ORDER BY pocet DESC, priezvisko, meno;


-- pacienti, ktori neboli na ziadnom vystreni
--s predikatom exist
SELECT p."id", p."first_name" AS meno, p."surename" AS priezvisko
FROM "patient" p
WHERE NOT EXISTS(
        SELECT *
        FROM "examination" e
        WHERE e."patient_id" = p."id"
        )
ORDER BY priezvisko, meno;

--pacieti, ktorí su alebo boli hospitalizovaný a neužívajú ani neuzivali žiadne lieky, na akom oddeleni
--s predikatom exist
SELECT p."first_name" AS meno, p."surename" AS priezvisko, d."name" AS oddelenie
FROM "patient" p
JOIN "hospitalization" h ON h."patient_id" = p."id"
JOIN "department" d ON d."id" = h."depart_id"
WHERE NOT EXISTS(SELECT *
                FROM "drug_used" du
                WHERE du."patient_id" = p."id")
ORDER BY oddelenie, priezvisko, meno;


-- pacienti, ktori maju zaznam o vysetreni a aj o hospitalizovani
-- IN s vnoreným SELCTom
SELECT p."id", p."first_name", p."surename" AS priezvisko
FROM "patient" p
WHERE p."id" IN (
        SELECT DISTINCT e."patient_id"
        FROM "hospitalization" h, "examination" e
        WHERE h."patient_id" = e."patient_id"
)
ORDER BY priezvisko; 

--doktori, ktorí majú uvezok a na urgente a sú ženy
-- IN s vnoreným SELCTom
SELECT e."first_name", e."surename" AS priezvisko
FROM "employee" e
JOIN "work" w ON w."doctor_id" = e."id"
JOIN "department" d ON d."id" = w."depart_id"
WHERE d."name" = 'Urgent' AND e."id"  IN (SELECT DISTINCT e."id"
                                        FROM  "employee" E
                                        WHERE E."gender" = 'žena')
ORDER BY priezvisko;



--------- PRISTUPOVE PRAVA ---------
GRANT ALL ON "department" TO xtvaro00;
GRANT ALL ON "drug" TO xtvaro00;
GRANT ALL ON "drug_used" TO xtvaro00;
GRANT ALL ON "employee" TO xtvaro00;
GRANT ALL ON "examination" TO xtvaro00;
GRANT ALL ON "hospitalization" TO xtvaro00;
GRANT ALL ON "patient" TO xtvaro00;
GRANT ALL ON "work" TO xtvaro00;

GRANT ALL ON "hospitalized_and_examinated" TO xtvaro00;

GRANT EXECUTE ON "average_income_nurse" TO xtvaro00;



--------- MATERIALIZED VIEW ---------

DROP MATERIALIZED VIEW "hospitalized_and_examinated";

-- log zmeny v tabulkach (aby sme mohli aktualizovat data)
CREATE MATERIALIZED VIEW LOG ON "patient" WITH PRIMARY KEY, ROWID;
CREATE MATERIALIZED VIEW LOG ON "examination" WITH PRIMARY KEY, ROWID;

-- pacienti, ktory maju vysetrenia
CREATE MATERIALIZED VIEW "hospitalized_and_examinated" 
    NOLOGGING
    CACHE
    BUILD IMMEDIATE
    REFRESH FAST ON COMMIT
    ENABLE QUERY REWRITE
AS
    SELECT p."id", p."first_name", p."surename", p.rowid AS patient_rowid, e.rowid AS exam_rowid
    FROM "patient" p
    JOIN "examination" e ON e."patient_id" = p."id";
/
--pristupove prava pre partaka
GRANT ALL ON "hospitalized_and_examinated"  TO xtvaro00;

-- Zobrazenie daneho materializovaneho pohladu
SELECT * FROM "hospitalized_and_examinated";

--vlozenie vysetrenia pacienta, ktory este na vysetreni nebol
INSERT INTO "examination" ("patient_id", "doctor_id", "depart_id", "date")
VALUES ('2', '2', '2', TO_TIMESTAMP('2021-03-17 08:00', 'YYYY-MM-DD HH24:MI.FF3'));

--commit updatne zmeny do pohladu
COMMIT;

--vypisanie pohladu.
SELECT * FROM "hospitalized_and_examinated";