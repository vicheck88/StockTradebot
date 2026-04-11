-- 별도재무제표 추가를 위한 DB 스키마 변경
-- 실행 전 반드시 백업 권장

-- Step 1: 연간/분기 재무제표에 연결구분 컬럼 추가 (기존 데이터는 '연결')
ALTER TABLE metainfo.연간재무제표 ADD COLUMN IF NOT EXISTS 연결구분 TEXT DEFAULT '연결';
ALTER TABLE metainfo.분기재무제표 ADD COLUMN IF NOT EXISTS 연결구분 TEXT DEFAULT '연결';

UPDATE metainfo.연간재무제표 SET 연결구분 = '연결' WHERE 연결구분 IS NULL;
UPDATE metainfo.분기재무제표 SET 연결구분 = '연결' WHERE 연결구분 IS NULL;

-- Step 2: 월별기업정보에 별도 FCF 컬럼 추가
ALTER TABLE metainfo.월별기업정보 ADD COLUMN IF NOT EXISTS 잉여현금흐름_별도 DOUBLE PRECISION;
