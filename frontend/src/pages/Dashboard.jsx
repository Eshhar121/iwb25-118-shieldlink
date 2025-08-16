import useAuth from "../hooks/useAuth";


export default function Dashboard() {
  const { user } = useAuth();

  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-gray-50">
      <h1 className="text-3xl font-bold mb-4">Dashboard</h1>
      {user ? (
        <div className="bg-white p-6 rounded-xl shadow">
          <p className="text-gray-700">Hello, {user.username} 👋</p>
          <p className="text-gray-500">Email: {user.email}</p>
        </div>
      ) : (
        <p>Loading user data...</p>
      )}
    </div>
  );
}
