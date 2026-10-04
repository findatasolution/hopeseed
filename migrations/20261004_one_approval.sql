-- Run once in Neon SQL Editor before deploying the updated review UI.
-- Safe to rerun. Keep listings with no approvals pending; never reopen rejected listings.
BEGIN;

CREATE OR REPLACE FUNCTION street_vendor_approvals_after_insert()
RETURNS trigger AS $$
DECLARE
  cnt int;
BEGIN
  SELECT count(*) INTO cnt FROM street_vendor_approvals WHERE vendor_id = NEW.vendor_id;
  IF cnt >= 1 THEN
    UPDATE street_vendors SET status = 'approved' WHERE id = NEW.vendor_id AND status = 'pending';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply the same rule to listings already waiting with at least one approval.
UPDATE street_vendors AS vendor
SET status = 'approved'
WHERE vendor.status = 'pending'
  AND EXISTS (
    SELECT 1 FROM street_vendor_approvals AS approval
    WHERE approval.vendor_id = vendor.id
  );

COMMIT;
