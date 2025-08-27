import { useState } from 'react'
import toast from 'react-hot-toast'
import { signup } from '../services/connectAPIs'
import { useNavigate ,Link } from 'react-router-dom'

export default function Register() {
    const [form, setForm] = useState({ name: '', email: '', password: '' })
    const [error, setError] = useState('')
    const [submitting, setSubmitting] = useState(false)
    const navigate = useNavigate()

    const handleChange = e => {
        setForm({ ...form, [e.target.name]: e.target.value })
    }

    const handleSubmit = async e => {
        e.preventDefault()
        setError('')
        setSubmitting(true)

        try {
            const res = await signup(form)
            if (res.status === 201) {
                toast.success(res.data.message || 'Signup successful!')
                navigate('/login')
            }
        } catch (err) {
            const status = err?.response?.status
            const message = err?.response?.data?.message || 'Signup failed. Try again.'

            if (status === 400 && message === 'User already exists') {
                setError(
                    <>
                        User already exists.{' '}
                        <Link to="/login" className="text-blue-600 underline hover:text-blue-800">
                            Login here
                        </Link>
                    </>
                )
            } else if (status === 500) {
                setError('Server error. Please try again later.')
            } else {
                setError(message)
            }
        } finally {
            setSubmitting(false)
        }
    }

    return (
        <div className="flex items-center justify-center min-h-screen bg-gradient-to-br from-purple-100 to-pink-200">
            <div className="w-full max-w-md bg-white p-8 rounded-xl shadow-md">
                <h2 className="text-3xl font-bold text-center text-gray-800 mb-6">
                    Create Your Account 🚀
                </h2>
                <form onSubmit={handleSubmit} className="space-y-4">
                    <input
                        name="name"
                        placeholder="Full Name"
                        value={form.name}
                        onChange={handleChange}
                        className="w-full p-3 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-indigo-500"
                        required
                    />
                    <input
                        name="email"
                        placeholder="Email"
                        type="email"
                        value={form.email}
                        onChange={handleChange}
                        className="w-full p-3 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-indigo-500"
                        required
                    />
                    <input
                        name="password"
                        placeholder="Password"
                        type="password"
                        value={form.password}
                        onChange={handleChange}
                        className="w-full p-3 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-indigo-500"
                        required
                    />
                    {error && <p className="text-red-500 text-sm">{error}</p>}
                    <button
                        type="submit"
                        disabled={submitting}
                        className="w-full bg-indigo-600 hover:bg-indigo-700 text-white py-3 rounded transition-colors duration-200"
                    >
                        Sign Up
                    </button>
                </form>
                <div className="mt-6 text-center text-gray-600">
                    <p>
                        Already have an account?{' '}
                        <Link to="/login" className="text-indigo-600 font-medium hover:underline">
                            Login here
                        </Link>
                    </p>
                </div>
            </div>
        </div>
    )
}
