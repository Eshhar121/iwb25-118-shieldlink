import { useState, useEffect } from 'react';
import AuthContext from './AuthContext';
import { getUser } from '../services/connectAPIs'

export function AuthProvider({ children }) {
  const [token, setToken] = useState(localStorage.getItem("token"));
  const [user, setUser] = useState(null);

  useEffect(() => {
    const fetchUser = async () => {
      try {
        if (token) {
          const userdata = await getUser(token); // ✅ wait for API
          setUser(userdata);
        }
      } catch (err) {
        console.error("Failed to fetch user:", err);
        setUser(null); // fallback
      }
    };
    fetchUser();
  }, [token]);

  const login = (newToken) => {
    localStorage.setItem("token", newToken);
    setToken(newToken);
  };

  const logout = () => {
    localStorage.removeItem("token");
    setToken(null);
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ token, user, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}
