
## 2. Huge Content-Length without Body (`MAL-POST-CL-HUGE-NO-BODY`)

*   **Decision:** **Implement Body Timeout.**
*   **Details:** We will implement a configurable duration timeout for reading the request body.
    *   **Default:** 1 minute.
    *   **Opt-out:** Allow `null` for YOLO mode.
*   **Status:** To be implemented in a future session.

## 4. OPTIONS with Body (`SMUG-OPTIONS-CL-BODY` & `SMUG-OPTIONS-CL-BODY-DESYNC`)

*   **Decision:** **Reject Request.**
*   **Details:** We will update the server to immediately reject `OPTIONS` requests containing a body with `400 Bad Request`. This prevents desync attacks without needing complex body-draining logic.
*   **Status:** To be implemented in a future session.
