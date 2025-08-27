import api from './axios';

// User Authentication
export const login = (credentials) => api.post('/auth/login', credentials);
export const signup = (data) => api.post('/auth/register', data);
export const getUser = async (token) => {
  const res = await api.get('/auth/user', {
    headers: { Authorization: `Bearer ${token}` },
  });
  return res.data;
};

// File Management
export const uploadFile = async (file, customName, accessLevel, token) => {
  const formData = new FormData();
  formData.append('file', file);
  if (customName) formData.append('customName', customName);
  if (accessLevel) formData.append('accessLevel', accessLevel);

  const res = await api.post('/file/upload', formData, {
    headers: {
      'Content-Type': 'multipart/form-data',
      Authorization: `Bearer ${token}`,
    },
  });

  return res.data;
};

export const getFiles = async (token) => {
  const res = await api.get('/file', {
    headers: { Authorization: `Bearer ${token}` },
  });
  return res.data.files;
};

export const getFile = async (fileIdOrName, token, apiKey) => {
  const headers = token ? { Authorization: `Bearer ${token}` } : {};
  const res = await api.get(`/file/${fileIdOrName}`, {
    headers,
    params: apiKey ? { key: apiKey } : {},
    responseType: 'blob',
  });
  return res.data;
};

export const deleteFile = async (fileId, token) => {
  const res = await api.delete(`/file/${fileId}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  return res.data;
};

export const updateFileAccess = async (fileId, accessLevel, token) => {
  const res = await api.patch(
    `/file/${fileId}/access`,
    { accessLevel },
    {
      headers: { Authorization: `Bearer ${token}` },
    }
  );
  return res.data;
};

// API Key Management
export const generateApiKey = async (token) => {
  const res = await api.post('/apikey', {}, {
    headers: { Authorization: `Bearer ${token}` },
  });
  return res.data;
};

export const getApiKeys = async (token) => {
  const res = await api.get('/apikey', {
    headers: { Authorization: `Bearer ${token}` },
  });
  return res.data;
};