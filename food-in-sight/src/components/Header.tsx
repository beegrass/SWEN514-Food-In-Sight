import {useNavigate} from "react-router-dom";
import "./Header.css";
import { useAuthenticator } from '@aws-amplify/ui-react';
import { FaHome, FaUser, FaCamera } from "react-icons/fa";


const Header = () => {
    const { user, signOut } = useAuthenticator((context) => [context.user]);

    const navigate = useNavigate();

    const handleProfileRedir = () => {
        navigate('/profile');
    };

    const handleHomeRedir = () => {
        navigate('/');
    }

    const handleCameraRedir = () => {
        navigate('/camera');
    }

    return (
        <header>
            <nav className="nav-menu">
                <button onClick={handleHomeRedir} className="nav-button">
                    <FaHome className="nav-icon"/>
                </button>
                <button onClick={handleProfileRedir} className="nav-button">
                    <FaUser className="nav-icon"/>
                </button>
                <button onClick={handleCameraRedir} className="nav-button">
                    <FaCamera className="nav-icon"/>
                </button>

                <p className="welcome-text">Welcome {user.username}</p>
                <button className="logout-button" onClick={signOut}>Sign Out</button>
            </nav>
        </header>
    );
};

export default Header;
