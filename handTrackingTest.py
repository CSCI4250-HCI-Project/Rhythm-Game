import cv2
import mediapipe as mp

imageWidth = 1280
imageHeight = 720

cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, value=imageWidth)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, value=imageHeight)

mp_drawing = mp.solutions.drawing_utils
mp_hands = mp.solutions.hands
hand = mp_hands.Hands()


i = 0
previous_landmark = {}
while True:
    success, frame = cap.read()
    if success:
        RGB_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        result = hand.process(RGB_frame)
        if result.multi_hand_landmarks:
            for hand_landmarks in result.multi_hand_landmarks:
                if i==0:
                    previous_landmark = hand_landmarks
                elif i == 10:
                    previous_landmark_wrist = previous_landmark.landmark[mp_hands.HandLandmark.WRIST]
                    current_landmark_wrist = hand_landmarks.landmark[mp_hands.HandLandmark.WRIST]
                    movementX = previous_landmark_wrist.x*imageWidth - current_landmark_wrist.x*imageWidth
                    movementY = previous_landmark_wrist.y*imageWidth - current_landmark_wrist.y*imageWidth
                    movementZ = previous_landmark_wrist.z*imageWidth - current_landmark_wrist.z*imageWidth
                    print("Distance hand has moved: ", (movementX,movementY,movementZ))
                    i = -1
                i += 1
                mp_drawing.draw_landmarks(frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)
        cv2.imshow("capture image", frame)
        if cv2.waitKey(1) == ord('q'):
            break

cv2.destroyAllWindows()