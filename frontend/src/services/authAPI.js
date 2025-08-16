import api from './axios';

export const login = (credentials) => api.post('/auth/login', credentials);
export const signup = (data) => api.post('/auth/register', data);
export const getUser = async (token) => {
  const res = await api.get(`auth/user`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  console.log(res.data);
  return res.data;  
};