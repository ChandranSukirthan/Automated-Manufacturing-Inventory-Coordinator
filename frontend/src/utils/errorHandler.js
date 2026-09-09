export const parseErrorMessage = (err, defaultMsg = 'An error occurred. Please try again.') => {
  if (!err) return defaultMsg;
  const data = err.response?.data;
  if (!data) {
    if (err.message === 'Network Error' || err.code === 'ERR_NETWORK') {
      return 'Network Error: Unable to connect to the backend server (http://localhost:5070). Please ensure the backend is running.';
    }
    return err.message || defaultMsg;
  }
  if (typeof data === 'string') return data;
  if (data.message) return data.message;
  if (data.errors && typeof data.errors === 'object') {
    const firstKey = Object.keys(data.errors)[0];
    if (firstKey && data.errors[firstKey] && data.errors[firstKey].length > 0) {
      return data.errors[firstKey][0];
    }
  }
  if (data.title) return data.title;
  return defaultMsg;
};

