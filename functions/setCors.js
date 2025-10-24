const { Storage } = require('@google-cloud/storage');

const storage = new Storage({
  projectId: 'nearme-970f3',
});

async function setCors() {
  const bucketName = 'nearme-970f3.firebasestorage.app';
  const cors = [
    {
      origin: ['https://nearme-970f3.web.app', 'https://nearme-970f3.firebaseapp.com'],
      method: ['GET', 'HEAD'],
      maxAgeSeconds: 3600,
    },
  ];

  try {
    await storage.bucket(bucketName).setCorsConfiguration(cors);
    console.log('CORS configuration set successfully');
  } catch (error) {
    console.error('Error setting CORS:', error);
  }
}

setCors();
