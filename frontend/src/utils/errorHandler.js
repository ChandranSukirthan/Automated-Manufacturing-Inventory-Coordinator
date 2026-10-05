export const parseErrorMessage = (err, defaultMsg = 'An error occurred. Please try again.') => {
  if (!err) return defaultMsg;

  const data = err.response?.data;
  if (data) {
    if (typeof data === 'string') return data;
    if (data.message) return data.message;
    if (typeof data.detail === 'string') return data.detail;
    if (Array.isArray(data.detail) && data.detail[0]?.msg) return data.detail[0].msg;
    if (data.errors && typeof data.errors === 'object') {
      const firstKey = Object.keys(data.errors)[0];
      if (firstKey && data.errors[firstKey] && data.errors[firstKey].length > 0) {
        return data.errors[firstKey][0];
      }
    }
    if (data.title) return data.title;
  }

  if (err.response?.status === 401) return 'Your session has expired. Please sign in again.';
  if (err.response?.status === 403) return 'You are not authorized to access this function.';
  if (err.response?.status === 404) return 'The requested resource was not found.';
  if (err.response?.status >= 500) return 'The backend encountered an error. Please try again shortly.';

  if (err.message === 'Network Error' || err.code === 'ERR_NETWORK') {
    return 'Network Error: Unable to connect to the backend server (http://localhost:5070). Please ensure the backend is running.';
  }

  return err.message || defaultMsg;
};

