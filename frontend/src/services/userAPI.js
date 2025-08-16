import api from './axios'

export const becomePublisher = () => api.patch('/user/become-publisher');