import React, { useState, useEffect } from 'react';
import { getFiles, uploadFile, deleteFile, updateFileAccess, getFile, generateApiKey, getApiKeys } from '../services/connectAPIs';
import useAuth from '../hooks/useAuth';

const Dashboard = () => {
  const { user, token } = useAuth();
  const [files, setFiles] = useState([]);
  const [selectedFile, setSelectedFile] = useState(null); // State for selected file
  const [apiKey, setApiKey] = useState(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const files = await getFiles(token);
        console.log(files);
        
        setFiles(files);

        const apiKeyData = await getApiKeys(token);
        setApiKey(apiKeyData.keyValue);
      } catch (error) {
        console.error('Error fetching data:', error);
      }
    };

    fetchData();
  }, [token]);

  const handleFileChange = (event) => {
    const file = event.target.files[0]; // Get the first selected file
    if (file) {
      setSelectedFile(file); // Update the state with the selected file
    }
  };

  const handleUpload = async () => {
    if (!selectedFile) {
      alert('Please select a file to upload.');
      return;
    }

    try {
      const newFile = await uploadFile(selectedFile, null, 'private', token); // Default access level: private
      setFiles((prevFiles) => [...prevFiles, newFile]);
      alert('File uploaded successfully!');
    } catch (error) {
      console.error('Error uploading file:', error);
    }
  };

  const handleDownload = async (fileId, fileName, accessLevel) => {
    try {
      const fileBlob = await getFile(fileId, token, accessLevel === 'public' ? apiKey : null);
      const url = window.URL.createObjectURL(new Blob([fileBlob]));
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', fileName);
      document.body.appendChild(link);
      link.click();
      link.parentNode.removeChild(link);
    } catch (error) {
      console.error('Error downloading file:', error);
    }
  };

  const handleDelete = async (fileId) => {
    const confirmDelete = window.confirm('Are you sure you want to delete this file?');
    if (!confirmDelete) return;

    try {
      await deleteFile(fileId, token);
      setFiles((prevFiles) => prevFiles.filter((file) => file.fileId !== fileId));
      alert('File deleted successfully!');
    } catch (error) {
      console.error('Error deleting file:', error);
    }
  };

  const handleAccessLevelChange = async (fileId, newAccessLevel) => {
    try {
      const updatedFile = await updateFileAccess(fileId, newAccessLevel, token);
      setFiles((prevFiles) =>
        prevFiles.map((file) => (file.fileId === fileId ? updatedFile : file))
      );
      alert('Access level updated successfully!');
    } catch (error) {
      console.error('Error updating access level:', error);
    }
  };

  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-gray-50">
      <h1 className="text-3xl font-bold mb-6">Dashboard</h1>
      {user ? (
        <div className="bg-white p-6 rounded-xl shadow-md mb-6 w-full max-w-md">
          <p className="text-gray-700 text-lg font-semibold">Hello, {user.username} 👋</p>
          <p className="text-gray-500">Email: {user.email}</p>
        </div>
      ) : (
        <p className="text-gray-700">Loading user data...</p>
      )}
      <div className="bg-white p-6 rounded-xl shadow-md mb-6 w-full max-w-md">
        <h2 className="text-xl font-semibold mb-4">Upload a File</h2>
        <div className="flex items-center space-x-4">
          <input
            type="file"
            onChange={handleFileChange}
            className="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
          />
          <button
            onClick={handleUpload}
            className="bg-blue-500 text-white px-4 py-2 rounded-lg hover:bg-blue-600 transition"
          >
            Upload
          </button>
        </div>
      </div>
      <div className="bg-white p-6 rounded-xl shadow-md w-full max-w-4xl mb-6">
        <h2 className="text-xl font-semibold mb-4">Uploaded Files</h2>
        {files.length > 0 ? (
          <table className="table-auto w-full text-left border-collapse">
            <thead>
              <tr className="bg-gray-100">
                <th className="px-4 py-2 border-b">Name</th>
                <th className="px-4 py-2 border-b">Created At</th>
                <th className="px-4 py-2 border-b">Access Level</th>
                <th className="px-4 py-2 border-b">Actions</th>
              </tr>
            </thead>
            <tbody>
              {files.map((file) => (
                <tr key={file.fileId}className="hover:bg-gray-50">
                  <td className="px-4 py-2 border-b">{file.originalName}</td>
                  <td className="px-4 py-2 border-b">{new Date(file.createdAt[1]).toLocaleString()}</td>
                  <td className="px-4 py-2 border-b">
                    <span
                      className={`inline-flex items-center px-2 py-1 rounded-full text-sm font-medium ${
                        file.accessLevel === 'private'
                          ? 'bg-red-100 text-red-800'
                          : file.accessLevel === 'read-only'
                          ? 'bg-blue-100 text-blue-800'
                          : 'bg-green-100 text-green-800'
                      }`}
                    >
                      {file.accessLevel === 'private' && '🔒 Private'}
                      {file.accessLevel === 'read-only' && '👀 Read-Only'}
                      {file.accessLevel === 'public' && '🌍 Public'}
                    </span>
                  </td>
                  <td className="px-4 py-2 border-b flex space-x-2">
                    {/* Download Button */}
                    <button
                      onClick={() => handleDownload(file.fileId, file.name, file.accessLevel)}
                      className="bg-green-500 text-white px-3 py-1 rounded-lg hover:bg-green-600 transition"
                    >
                      Download
                    </button>

                    {/* Delete Button (Only for Private Files) */}
                    {file.accessLevel === 'private' && (
                      <button
                        onClick={() => handleDelete(file.fileId)}
                        className="bg-red-500 text-white px-3 py-1 rounded-lg hover:bg-red-600 transition"
                      >
                        Delete
                      </button>
                    )}

                    {/* Access Level Dropdown (Only for Private Files) */}
                    {file.accessLevel === 'private' && (
                      <select
                        value={file.accessLevel}
                        onChange={(e) => handleAccessLevelChange(file.fileId, e.target.value)}
                        className="bg-gray-100 border border-gray-300 rounded-lg px-2 py-1 text-sm"
                      >
                        <option value="private">🔒 Private</option>
                        <option value="read-only">👀 Read-Only</option>
                        <option value="public">🌍 Public</option>
                      </select>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <p className="text-gray-500">No files uploaded yet.</p>
        )}
      </div>
    </div>
  );
};

export default Dashboard;
