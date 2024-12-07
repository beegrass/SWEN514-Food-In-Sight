import { Amplify } from 'aws-amplify';
import { Authenticator, ThemeProvider} from '@aws-amplify/ui-react';
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom'; // Import Router and Route
import '@aws-amplify/ui-react/styles.css';

import awsmobile from "aws-exports";

import LandingPage from "./components/LandingPage.tsx";
import Header from "./components/Header.tsx";
import ResultsPage from "./components/ResultsPage.tsx";
import ProfilePage from "./components/ProfilePage.tsx";
import TranslateResults from "./components/TranslateResult.tsx";
import CameraPage from './components/CameraPage.tsx';

Amplify.configure(awsmobile);

export default function App() {
    return (
        <ThemeProvider theme={foodtheme}>
            <Authenticator>
                {({user }) => (

                        <Router> {/* Wrap everything with Router */}
                            {user ? (
                                <main>
                                    <Header/>

                                    <Routes>
                                        <Route path="/" element={<LandingPage />} />
                                        <Route path="/profile" element={<ProfilePage />} />
                                        <Route path="/results" element={<ResultsPage />} />
                                        <Route path="/translatedResults" element={<TranslateResults />} />
                                        <Route path="/camera" element={<CameraPage />} />
                                    </Routes>

                                </main>
                            ) : (
                                <p>Loading</p>
                            )}
                        </Router>
                )}
            </Authenticator>
        </ThemeProvider>
    );
}


const foodtheme = {
    name: 'food-in-sight',
    tokens: {
        colors: {
            border: {
                primary: { value: '#F7EED3' },
                secondary: { value: '#AAB396' },
                tertiary: { value: '#674636' },
            },
        },
        radii: {
            small: { value: '2px' },
            medium: { value: '3px' },
            large: { value: '4px' },
            xl: { value: '6px' },
        },
    },
};