// Use same-origin by default; nginx will proxy /api to backend
export const BASE_API_URL = process.env.REACT_APP_API_URL || "";
