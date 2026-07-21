import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: 'AIzaSyBPyH2zjOLHAo2KXks4Ze1ZnZcdYnjX3qY',
  authDomain: 'smart-expense-manager-1210chay.firebaseapp.com',
  projectId: 'smart-expense-manager-1210chay',
  storageBucket: 'smart-expense-manager-1210chay.firebasestorage.app',
  messagingSenderId: '620730155211',
  appId: '1:620730155211:web:b9f8217019f836a46b5b4e',
  measurementId: 'G-LYJ1QC7071',
};

const app = initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const db = getFirestore(app);
