-- MIGRATION 1: Status flow and history triggers (Phase 3)

-- 1. Append-only enforcement for tracking_event (R7)
CREATE OR REPLACE FUNCTION public.fn_prevent_history_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    RAISE EXCEPTION 'Tracking history is append-only. Updates and deletions are forbidden (R7).';
END;
$$;

CREATE TRIGGER trg_tracking_event_append_only
    BEFORE UPDATE OR DELETE ON public.tracking_event
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_prevent_history_mutation();

-- 2. Status validation trigger (R6)
CREATE OR REPLACE FUNCTION public.fn_validate_tracking_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    v_latest_event record;
    v_new_seq integer;
    v_old_seq integer;
    v_old_terminal boolean;
    v_new_terminal boolean;
BEGIN
    -- Acquire row-level lock on the package to ensure strictly serializable event evaluation
    -- and prevent race conditions with concurrent status updates.
    PERFORM 1 FROM public.package 
    WHERE package_id = NEW.package_id 
    FOR NO KEY UPDATE;

    -- Fetch the most recent event for this package
    SELECT * INTO v_latest_event
    FROM public.tracking_event
    WHERE package_id = NEW.package_id
    ORDER BY event_time DESC
    LIMIT 1;

    -- Fetch properties of the new status
    SELECT sequence_no, is_terminal INTO v_new_seq, v_new_terminal
    FROM public.status_code
    WHERE status_code = NEW.status_code;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid status_code: %', NEW.status_code;
    END IF;

    IF v_latest_event IS NULL THEN
        -- First event must be REGISTERED
        IF NEW.status_code <> 'REGISTERED' THEN
            RAISE EXCEPTION 'First tracking event must be REGISTERED (R6).';
        END IF;
    ELSE
        -- Ensure timeline moves forward strictly
        IF NEW.event_time <= v_latest_event.event_time THEN
            RAISE EXCEPTION 'New event time must be strictly later than the latest existing event time.';
        END IF;

        -- Fetch properties of the old status
        SELECT sequence_no, is_terminal INTO v_old_seq, v_old_terminal
        FROM public.status_code
        WHERE status_code = v_latest_event.status_code;

        -- Cannot transition from terminal status
        IF v_old_terminal THEN
            RAISE EXCEPTION 'Cannot add tracking event after a terminal status (%).', v_latest_event.status_code;
        END IF;

        -- Transition logic
        IF NEW.status_code = v_latest_event.status_code THEN
            -- Repeating the same status is allowed
            NULL;
        ELSIF NEW.status_code = 'RETURNED' THEN
            -- Allowed from any non-terminal status
            NULL;
        ELSE
            -- Normal transition must advance exactly one step
            IF v_new_seq - v_old_seq <> 1 THEN
                RAISE EXCEPTION 'Invalid status transition from % to % (R6).', v_latest_event.status_code, NEW.status_code;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_tracking_event_status_flow
    BEFORE INSERT ON public.tracking_event
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_validate_tracking_status();

-- 3. Package current status cache synchronization
CREATE OR REPLACE FUNCTION public.fn_sync_package_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    UPDATE public.package
    SET current_status = NEW.status_code
    WHERE package_id = NEW.package_id;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_tracking_event_sync_status
    AFTER INSERT ON public.tracking_event
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_sync_package_status();
